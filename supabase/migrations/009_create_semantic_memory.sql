-- Migration: Add Semantic Vector Search to Memories
-- Description: Adds a vector embedding column, an HNSW index, and a match_memories RPC.

-- Add the embedding column
ALTER TABLE public.memories ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Create an HNSW index for fast approximate nearest neighbor search using cosine distance
CREATE INDEX IF NOT EXISTS memories_embedding_idx ON public.memories USING hnsw (embedding vector_cosine_ops);

-- Create the match_memories RPC function
-- This allows us to query memories by similarity from the FastAPI backend using Supabase RPC
DROP FUNCTION IF EXISTS match_memories(vector, float, int, uuid);

CREATE OR REPLACE FUNCTION match_memories(
    query_embedding vector(384),
    match_threshold float,
    match_count int,
    p_user_id uuid
)
RETURNS TABLE (
    id uuid,
    content text,
    category text,
    similarity float
)
LANGUAGE sql STABLE
AS $$
    SELECT
        memories.id,
        memories.content,
        memories.category,
        1 - (memories.embedding <=> query_embedding) AS similarity
    FROM public.memories
    WHERE memories.user_id = p_user_id
        -- We only want memories that actually have an embedding
        AND memories.embedding IS NOT NULL
        -- The cosine distance '<=>' is (1 - cosine_similarity), 
        -- so to find items with similarity > threshold, we need distance < (1 - threshold)
        AND 1 - (memories.embedding <=> query_embedding) > match_threshold
    ORDER BY memories.embedding <=> query_embedding
    LIMIT match_count;
$$;
