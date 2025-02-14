import { serve } from 'https:
import { createClient } from 'https:

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405 }
    );
  }

  try {
    const { league_room_id } = await req.json();
    console.log('Getting points for league room:', league_room_id);

    
    
    const { data: teamChallenges, error: challengesError } = await supabase
      .from('team_challenges')
      .select(`
        team_id,
        multiplier,
        teams!inner (
          team_id,
          team_name,
          league_room_id
        ),
        challenges!inner (
          earning_points
        ),
        iscompleted
      `)
      .eq('teams.league_room_id', league_room_id)
      .eq('iscompleted', true);

    if (challengesError) {
      console.error('Error fetching team challenges:', challengesError);
      return new Response(
        JSON.stringify({ error: challengesError.message }),
        { status: 400 }
      );
    }

    
    const teamPoints = new Map();
    teamChallenges.forEach(tc => {
      const teamId = tc.team_id;
      const basePoints = tc.challenges.earning_points || 0;
      const multiplier = tc.multiplier || 1;
      const points = basePoints * multiplier;
      const teamName = tc.teams.team_name;

      if (!teamPoints.has(teamId)) {
        teamPoints.set(teamId, {
          team_id: teamId,
          team_name: teamName,
          total_points: 0,
          completed_challenges: 0
        });
      }

      const team = teamPoints.get(teamId);
      team.total_points += points;
      team.completed_challenges += 1;
    });

    
    const teamsWithPoints = Array.from(teamPoints.values())
      .sort((a, b) => b.total_points - a.total_points);

    console.log('Teams with points:', teamsWithPoints);

    return new Response(
      JSON.stringify({ data: teamsWithPoints }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500 }
    );
  }
});
