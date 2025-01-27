import { serve } from 'https:
import { createClient } from 'https:

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  try {
    const { league_room_id } = await req.json();
    console.log('Processing request for league_room_id:', league_room_id);

    const { data, error } = await supabase
      .from('teams')
      .select(`
        team_id,
        team_name,
        team_memberships (
          user_id,
          user:users (
            name
          )
        )
      `)
      .eq('league_room_id', league_room_id);

    if (error) throw error;

    
    const transformedData = data.map(team => ({
      team_name: team.team_name,
      team_id: team.team_id,
      members: team.team_memberships.map(membership => ({
        name: membership.user.name,
        user_id: membership.user_id
      }))
    }));

    console.log('Sending response:', transformedData);

    return new Response(JSON.stringify(transformedData), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Error:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});