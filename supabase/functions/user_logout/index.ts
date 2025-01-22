import { serve } from 'https:
import { createClient } from 'https:

console.log(`Function "user_logout" is up and running!`);

serve(async (req) => {
  try {
    
    if (req.method !== 'POST') {
      console.log(`Received non-POST request: ${req.method}`);
      return new Response(JSON.stringify({ error: 'Method Not Allowed' }), { status: 405 });
    }

    
    const bodyText = await req.text();
    console.log(`Raw request body: ${bodyText}`);

    if (!bodyText.trim()) {
      console.warn('Empty request body received.');
      return new Response(JSON.stringify({ error: 'Request body cannot be empty.' }), {
        status: 400,
      });
    }

    
    let userId: number;
    try {
      const parsedBody = JSON.parse(bodyText);
      userId = parsedBody.user_id;
    } catch (error) {
      console.error('JSON parsing error:', error);
      return new Response(JSON.stringify({ error: 'Invalid JSON format.' }), { status: 400 });
    }

    console.log(`Parsed user_id: ${userId}`);

    if (!userId || typeof userId !== 'number') {
      console.log('Invalid or missing user_id.');
      return new Response(JSON.stringify({ error: 'Invalid or missing user_id.' }), {
        status: 400,
      });
    }

    
    
    
    
    

    

    console.log(`User with ID ${userId} "logged out" (dummy).`);
    const successResponse = {
      message: 'User logged out successfully (no server session).',
    };

    return new Response(JSON.stringify(successResponse), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error('Unexpected error:', error);

    return new Response(
      JSON.stringify({ error: 'Internal Server Error' }),
      { status: 500 }
    );
  }
});
