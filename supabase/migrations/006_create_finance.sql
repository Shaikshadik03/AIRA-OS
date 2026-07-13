-- ============================================
-- AIRA OS: Finance System
-- ============================================

-- Categories
CREATE TABLE finance_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    color TEXT,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    is_default BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_finance_categories_user ON finance_categories(user_id);

-- Transactions
CREATE TABLE finance_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES finance_categories(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    title TEXT NOT NULL,
    notes TEXT,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_finance_transactions_user ON finance_transactions(user_id);
CREATE INDEX idx_finance_transactions_date ON finance_transactions(user_id, transaction_date DESC);

-- Budgets
CREATE TABLE finance_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES finance_categories(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    period TEXT DEFAULT 'monthly' CHECK (period IN ('weekly', 'monthly', 'yearly')),
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_finance_budgets_user ON finance_budgets(user_id);

-- Auto-create default categories for new users
CREATE OR REPLACE FUNCTION create_default_finance_categories()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO finance_categories (user_id, name, icon, color, type, is_default) VALUES
        (NEW.id, 'Food & Dining', '🍔', '#F59E0B', 'expense', TRUE),
        (NEW.id, 'Transport', '🚗', '#3B82F6', 'expense', TRUE),
        (NEW.id, 'Shopping', '🛒', '#EC4899', 'expense', TRUE),
        (NEW.id, 'Entertainment', '🎮', '#8B5CF6', 'expense', TRUE),
        (NEW.id, 'Bills & Utilities', '💡', '#EF4444', 'expense', TRUE),
        (NEW.id, 'Health', '💊', '#10B981', 'expense', TRUE),
        (NEW.id, 'Education', '📚', '#06B6D4', 'expense', TRUE),
        (NEW.id, 'Salary', '💰', '#10B981', 'income', TRUE),
        (NEW.id, 'Freelance', '💻', '#7C3AED', 'income', TRUE),
        (NEW.id, 'Other', '📦', '#6B7280', 'expense', TRUE);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_add_finance_categories
    AFTER INSERT ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_default_finance_categories();

-- Row Level Security
ALTER TABLE finance_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own finance_categories" ON finance_categories FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can CRUD own finance_transactions" ON finance_transactions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can CRUD own finance_budgets" ON finance_budgets FOR ALL USING (auth.uid() = user_id);
