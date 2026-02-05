# Supabase Setup Guide

This guide will help you set up Supabase for your Flutter app to store trade signals persistently.

## Step 1: Create the Database Table

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `rffexsyqlwahiqiwndyd`
3. Navigate to **SQL Editor** (left sidebar)
4. Click **New Query**
5. Copy and paste the entire contents of `supabase_migration.sql` file
6. Click **Run** to execute the migration

This will create:
- The `trade_signals` table with all necessary columns
- Indexes for better query performance
- Row Level Security (RLS) policies
- Automatic timestamp updates

## Step 2: Enable Row Level Security (RLS)

The migration script already enables RLS and creates a policy for anonymous access. However, you should verify:

1. Go to **Authentication** → **Policies** in your Supabase dashboard
2. Find the `trade_signals` table
3. Ensure the policy "Allow all operations for anon users" exists and is enabled

If you want to restrict access later, you can modify the policy or add authentication.

## Step 3: Verify API Settings

1. Go to **Settings** → **API** in your Supabase dashboard
2. Verify that:
   - **Project URL**: `https://rffexsyqlwahiqiwndyd.supabase.co`
   - **anon public key**: Matches the one in your code (already configured)
   - **service_role key**: Keep this secret (already configured)

## Step 4: Test the Connection

1. Run `flutter pub get` to install the Supabase package
2. Run your Flutter app
3. Create a new signal in the app
4. Check your Supabase dashboard:
   - Go to **Table Editor** → **trade_signals**
   - You should see your signal data there

## Step 5: Enable Real-time (Optional)

If you want real-time updates across multiple devices:

1. Go to **Database** → **Replication** in Supabase dashboard
2. Enable replication for the `trade_signals` table
3. This allows the app to receive updates when signals change

## Troubleshooting

### Error: "relation 'trade_signals' does not exist"
- Make sure you ran the SQL migration script in Step 1

### Error: "new row violates row-level security policy"
- Check that RLS policies are enabled and the anonymous policy exists
- Verify the policy allows INSERT, UPDATE, DELETE, and SELECT operations

### Error: "Failed to initialize Supabase"
- Check your internet connection
- Verify the Supabase URL and anon key are correct
- Check Supabase dashboard to ensure your project is active

### Signals not appearing
- Check the Supabase dashboard Table Editor to see if data is being saved
- Check the app console for error messages
- Verify the migration script ran successfully

## Security Notes

- The current setup uses anonymous access for simplicity
- For production, consider:
  - Adding user authentication
  - Restricting RLS policies based on user roles
  - Using service role key only on the server side

## Next Steps

After setup is complete:
1. Your signals will automatically save to Supabase
2. Signals will persist across app restarts
3. You can view all signals in the Supabase dashboard
4. Signals are synced in real-time if you enable replication
