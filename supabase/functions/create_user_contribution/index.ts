import { serve } from 'https:
import { createClient } from 'https:

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  try {
    const body = await req.json();
    console.log('Received request body:', body);

    
    const {
      user_id,
      start_time,
      end_time,
      start_latitude,
      start_longitude,
      end_latitude,
      end_longitude,
      distance_covered,
    } = body;

    const validationErrors = [];
    if (typeof user_id !== 'number') validationErrors.push('user_id must be a number');
    if (typeof start_time !== 'string') validationErrors.push('start_time must be a string');
    if (typeof distance_covered !== 'number') validationErrors.push('distance_covered must be a number');

    if (validationErrors.length > 0) {
      return new Response(
        JSON.stringify({ error: 'Validation failed', details: validationErrors }),
        { status: 400 }
      );
    }

    
    const { data: teamMembership, error: teamError } = await supabase
      .from('team_memberships')
      .select('team_id')
      .eq('user_id', user_id)
      .is('date_left', null)
      .single();

    if (teamError) {
      console.error('Team error:', teamError);
      return new Response(
        JSON.stringify({ error: 'Failed to get team membership' }),
        { status: 400 }
      );
    }

    
    const { data: teamChallenge, error: challengeError } = await supabase
      .from('team_challenges')
      .select(`
        team_challenge_id,
        challenges (
          length
        )
      `)
      .eq('team_id', teamMembership.team_id)
      .eq('iscompleted', false)
      .order('team_challenge_id', { ascending: false })
      .limit(1)
      .single();

    if (challengeError || !teamChallenge) {
      console.error('Challenge error:', challengeError);
      return new Response(
        JSON.stringify({ error: 'No active challenge found' }),
        { status: 400 }
      );
    }

    
    const { data: newContribution, error: insertError } = await supabase
      .from('user_contributions')
      .insert({
        team_challenge_id: teamChallenge.team_challenge_id,
        user_id,
        start_time,
        end_time: end_time ?? new Date().toISOString(),
        start_latitude,
        start_longitude,
        end_latitude,
        end_longitude,
        distance_covered,
        active: false,
        contribution_details: `Distance covered: ${distance_covered}m`
      })
      .select()
      .single();

    if (insertError) {
      console.error('Insert error:', insertError);
      return new Response(
        JSON.stringify({ error: 'Failed to save contribution' }),
        { status: 400 }
      );
    }

    
    const { data: allContributions, error: sumError } = await supabase
      .from('user_contributions')
      .select('distance_covered')
      .eq('team_challenge_id', teamChallenge.team_challenge_id);

    if (sumError) {
      console.error('Sum error:', sumError);
      return new Response(
        JSON.stringify({ error: 'Failed to calculate total distance' }),
        { status: 400 }
      );
    }

    
    const totalMeters = allContributions.reduce((sum, c) => sum + (c.distance_covered || 0), 0);
    const totalKm = totalMeters / 1000;
    const requiredKm = teamChallenge.challenges.length;
    const isCompleted = totalKm >= requiredKm;

    
    if (isCompleted) {
      const { error: updateError } = await supabase
        .from('team_challenges')
        .update({ iscompleted: true })
        .eq('team_challenge_id', teamChallenge.team_challenge_id);

      if (updateError) {
        console.error('Update error:', updateError);
      }
    }

    
    const response = {
      data: {
        ...newContribution,
        challenge_completed: isCompleted,
        total_distance_km: totalKm,
        required_distance_km: requiredKm
      }
    };

    console.log('Sending response:', JSON.stringify(response, null, 2));

    return new Response(
      JSON.stringify(response),
      {
        status: 201,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: err.message }),
      { status: 500 }
    );
  }
});