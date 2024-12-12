import { createClient } from 'https:
import { serve } from 'https:


const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''


const supabase = createClient(supabaseUrl, supabaseKey)

serve(async (req: Request) => {
  
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  
  let body: any
  try {
    body = await req.json()
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400 })
  }

  
  const { start_time, duration, earning_points, difficulty, type } = body
  if (!start_time || !duration || !earning_points || !difficulty || !type) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400 })
  }

  
  const { data, error } = await supabase
    .from('challenges')
    .insert({
      start_time,      
      duration,        
      earning_points,  
      difficulty,      
      type             
    })
    .select('*') 

  
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }

  
  return new Response(JSON.stringify({ data }), { status: 201 })
})