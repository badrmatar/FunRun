import { serve } from 'https:
import { createClient } from 'https:


const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''


const supabase = createClient(supabaseUrl, supabaseKey)

serve(async (req: Request) => {
  try {
    
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
      })
    }

    
    let body: any
    try {
      body = await req.json()
    } catch (_error) {
      return new Response(JSON.stringify({
        error: 'Invalid JSON body.',
      }), { status: 400 })
    }

    const { user_id } = body

    
    if (typeof user_id !== 'number') {
      return new Response(JSON.stringify({
        error: 'user_id must be a number.',
      }), { status: 400 })
    }

    
    const { data: waitingRoomRow, error: findWrError } = await supabase
      .from('waiting_rooms')
      .select('waiting_room_id')
      .eq('user_id', user_id)
      .is('league_room_id', null)
      .maybeSingle()

    if (findWrError) {
      return new Response(JSON.stringify({ error: findWrError.message }), {
        status: 400,
      })
    }

    if (!waitingRoomRow) {
      
      return new Response(JSON.stringify({
        error: 'No active waiting room found for this user.',
      }), { status: 404 })
    }

    const waiting_room_id = waitingRoomRow.waiting_room_id

    
    const { data: waitingUsers, error: waitingUsersError } = await supabase
      .from('waiting_rooms')
      .select('waiting_room_id, user_id')
      .eq('waiting_room_id', waiting_room_id)
      .is('league_room_id', null)

    if (waitingUsersError) {
      return new Response(JSON.stringify({ error: waitingUsersError.message }), {
        status: 400,
      })
    }

    if (!waitingUsers || waitingUsers.length === 0) {
      return new Response(JSON.stringify({
        error: 'No users found in this waiting room.',
      }), { status: 404 })
    }

    
    
    const leagueRoomName = `New League Room - ${new Date().toISOString()}`
    const { data: newLeagueRoom, error: leagueRoomError } = await supabase
      .from('league_rooms')
      .insert({ league_room_name: leagueRoomName })
      .select('league_room_id, league_room_name')
      .single()

    if (leagueRoomError || !newLeagueRoom) {
      return new Response(JSON.stringify({
        error: leagueRoomError?.message || 'Failed to create a league room.',
      }), { status: 400 })
    }

    
    const { data: updatedRows, error: updateError } = await supabase
      .from('waiting_rooms')
      .update({ league_room_id: newLeagueRoom.league_room_id })
      .eq('waiting_room_id', waiting_room_id)
      .is('league_room_id', null)
      .select()

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 400,
      })
    }

    
    return new Response(JSON.stringify({
      message: 'Successfully moved users to new league room.',
      league_room_id: newLeagueRoom.league_room_id,
      league_room_name: newLeagueRoom.league_room_name,
      total_users_moved: updatedRows?.length ?? 0,
      updated_rows: updatedRows,
    }), { status: 200 })
  } catch (error) {
    console.error('Unexpected error:', error)
    const environment = Deno.env.get('ENVIRONMENT') || 'production'
    const isDevelopment = environment === 'development'
    const errorMessage = isDevelopment
      ? `Internal Server Error: ${error instanceof Error ? error.message : String(error)}`
      : 'Internal Server Error'

    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
    })
  }
})
