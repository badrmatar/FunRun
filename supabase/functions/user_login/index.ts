import { serve } from 'https:
import { createClient } from 'https:
import * as bcrypt from 'https:

console.log(`Function "user_login" is up and running!`);

serve(async (req) => {
  try {
    
    const { email, password } = await req.json();

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: 'Email and password are required.' }),
        { status: 400 }
      );
    }

    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    console.log(supabaseUrl);
    console.log(supabaseKey);
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log('Supabase client initialized.');
    
    const { data: user, error } = await supabase
      .from('users')
      .select('id, email, password')
      .eq('email', email)
      .maybeSingle();

    console.log(`user --> ${user}, error --> ${error}`);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
      });
    }

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Invalid email or password.' }),
        { status: 401 }
      );
    }

    
    const passwordMatch = await bcrypt.compare(password, user.password);

    if (!passwordMatch) {
      return new Response(
        JSON.stringify({ error: 'Invalid email or password.' }),
        { status: 401 }
      );
    }

    
    return new Response(
      JSON.stringify({
        message: 'Authentication successful.',
        user_id: user.id,
        email: user.email,
        
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  }catch (error) {
       console.error('Unexpected error:', error);

       
       const environment = Deno.env.get('ENVIRONMENT') || 'production';
       const isDevelopment = environment === 'development';

       
       let errorMessage = 'Internal Server Error';
       if (isDevelopment) {
         
         const errorDetails = error instanceof Error ? error.message : String(error);
         errorMessage = Internal Server Error: ${errorDetails};
       }

       return new Response(JSON.stringify({ error: errorMessage }), {
         status: 500,
         headers: { 'Content-Type': 'application/json' },
       });
     }
});