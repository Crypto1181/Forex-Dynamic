-- Migration script for trade_signals table
-- Run this in your Supabase SQL Editor

-- Create the trade_signals table
CREATE TABLE IF NOT EXISTS trade_signals (
  trade_id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('BUY', 'SELL')),
  entry_time TEXT NOT NULL,
  entry_price DOUBLE PRECISION DEFAULT 0.0,
  tp DOUBLE PRECISION NOT NULL,
  sl DOUBLE PRECISION NOT NULL,
  tp_condition1 TEXT,
  tp_condition2 TEXT,
  new_tp DOUBLE PRECISION,
  lot DOUBLE PRECISION NOT NULL,
  is_daily BOOLEAN DEFAULT false,
  daily_tp DOUBLE PRECISION,
  daily_lot DOUBLE PRECISION,
  account_name TEXT NOT NULL DEFAULT '',
  brand TEXT NOT NULL DEFAULT '',
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_draft BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create an index on received_at for faster sorting
CREATE INDEX IF NOT EXISTS idx_trade_signals_received_at ON trade_signals(received_at DESC);

-- Create an index on is_draft for filtering drafts
CREATE INDEX IF NOT EXISTS idx_trade_signals_is_draft ON trade_signals(is_draft);

-- Enable Row Level Security (RLS)
ALTER TABLE trade_signals ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows all operations for authenticated users
-- For anonymous access (using anon key), we'll allow all operations
CREATE POLICY "Allow all operations for anon users" ON trade_signals
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Optional: Create a policy for authenticated users if you add authentication later
-- CREATE POLICY "Allow all operations for authenticated users" ON trade_signals
--   FOR ALL
--   USING (auth.role() = 'authenticated')
--   WITH CHECK (auth.role() = 'authenticated');

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create a trigger to automatically update updated_at
CREATE TRIGGER update_trade_signals_updated_at
  BEFORE UPDATE ON trade_signals
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
