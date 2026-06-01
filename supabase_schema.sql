-- ==========================================================
-- CINEGRAM SUPABASE DATABASE SCHEMA
-- Copy and run this script in your Supabase SQL Editor!
-- ==========================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE (User account profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    name TEXT NOT NULL,
    avatar_url TEXT,
    preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. MEDIA LISTINGS TABLE (Telegram media storage index)
CREATE TABLE IF NOT EXISTS public.media_listings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    tmdb_id TEXT NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('movie', 'tv', 'anime')),
    channel_id TEXT NOT NULL,
    message_id TEXT NOT NULL,
    quality TEXT DEFAULT '1080p',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(channel_id, message_id)
);

-- 3. WATCH HISTORY TABLE (Continue Watching progress sync)
CREATE TABLE IF NOT EXISTS public.watch_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    media_listing_id UUID REFERENCES public.media_listings ON DELETE CASCADE NOT NULL,
    position_ms INTEGER NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    progress_percent REAL NOT NULL DEFAULT 0.0,
    last_watched TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, media_listing_id)
);

-- 4. BOOKMARKS TABLE (User bookmarks/vault list)
CREATE TABLE IF NOT EXISTS public.bookmarks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    media_listing_id UUID REFERENCES public.media_listings ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, media_listing_id)
);

-- Enable Row Level Security (RLS) on all tables for security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.media_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_listings DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.watch_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------
-- Row Level Security (RLS) Policies
-- ----------------------------------------------------

-- Profiles Policies
CREATE POLICY "Allow public read access to profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow users to update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow users to insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Media Listings Policies (Public read, admin/authenticated write)
CREATE POLICY "Allow anyone to read media listings" ON public.media_listings FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to insert listings" ON public.media_listings FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users to update listings" ON public.media_listings FOR UPDATE USING (auth.role() = 'authenticated');

-- Watch History Policies (Private read/write to owner)
CREATE POLICY "Allow users to read own watch history" ON public.watch_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert own watch history" ON public.watch_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update own watch history" ON public.watch_history FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Allow users to delete own watch history" ON public.watch_history FOR DELETE USING (auth.uid() = user_id);

-- Bookmarks Policies (Private read/write to owner)
CREATE POLICY "Allow users to read own bookmarks" ON public.bookmarks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert own bookmarks" ON public.bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete own bookmarks" ON public.bookmarks FOR DELETE USING (auth.uid() = user_id);
