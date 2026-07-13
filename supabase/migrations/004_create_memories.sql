-- ============================================
-- AIRA OS: Long-Term Semantic Memory
-- ============================================

CREATE TABLE memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    category TEXT DEFAULT 'general' CHECK (category IN ('general', 'preference', 'fact', 'habit', 'goal', 'note')),
    embedding VECTOR(1536),
    importance_score FLOAT DEFAULT 0.5 CHECK (importance_score >= 0 AND importance_score <= 1),
    source_conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_memories_user ON memories(user_id);
CREATE INDEX idx_memories_category ON memories(user_id, category);
CREATE INDEX idx_memories_embedding ON memories
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION match_memories(
    query_embedding VECTOR(1536),
    match_threshold FLOAT,
    match_count INT,
    p_user_id UUID
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    category TEXT,
    importance_score FLOAT,
    similarity FLOAT
)
LANGUAGE sql STABLE
AS $$
    SELECT
        memories.id,
        memories.content,
        memories.category,
        memories.importance_score,
        1 - (memories.embedding <=> query_embedding) AS similarity
    FROM memories
    WHERE memories.user_id = p_user_id
        AND 1 - (memories.embedding <=> query_embedding) > match_threshold
        AND (memories.expires_at IS NULL OR memories.expires_at > NOW())
    ORDER BY (memories.embedding <=> query_embedding)
    LIMIT match_count;
$$;

-- Row Level Security
ALTER TABLE memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own memories"
    ON memories FOR ALL
    USING (auth.uid() = user_id);
