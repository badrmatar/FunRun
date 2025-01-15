

import { serve } from 'https:
import { createClient } from 'https:


const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseKey)

console.log(`Edge function "get_waiting_room_users" is running...`)



serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
      })
    }

    const body = await req.json().catch(() => null)
    if (!body || typeof body.waiting_room_id !== 'number') {
      return new Response(
        JSON.stringify({ error: 'Invalid or missing "waiting_room_id".' }),
        { status: 400 }
      )
    }

    const waitingRoomId = body.waiting_room_id

    
    const { data: waitingRoomRows, error: waitingRoomError } = await supabase
      .from('waiting_rooms')
      .select('user_id')
      .eq('waiting_room_id', waitingRoomId)

    if (waitingRoomError) {
      return new Response(JSON.stringify({ error: waitingRoomError.message }), {
        status: 400,
      })
    }

    if (!waitingRoomRows || waitingRoomRows.length === 0) {
      
      return new Response(JSON.stringify([]), { status: 200 })
    }

    
    const userIds = waitingRoomRows.map((row) => row.user_id)

    
    
    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select('user_id, name')
      .in('user_id', userIds)

    if (usersError) {
      return new Response(JSON.stringify({ error: usersError.message }), {
        status: 400,
      })
    }

    
    
    return new Response(JSON.stringify(usersData), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Unexpected error:', error)
    
    return new Response(
      JSON.stringify({ error: 'Internal Server Error' }),
      { status: 500 }
    )
  }
})
