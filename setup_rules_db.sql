-- Create the hostel_rules table
CREATE TABLE IF NOT EXISTS public.hostel_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hostel_name TEXT NOT NULL,
    extracted_text TEXT NOT NULL,
    file_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.hostel_rules ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (since the app currently operates without strict auth)
CREATE POLICY "Allow public read access on hostel_rules" 
ON public.hostel_rules FOR SELECT USING (true);

CREATE POLICY "Allow public insert on hostel_rules" 
ON public.hostel_rules FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public delete on hostel_rules" 
ON public.hostel_rules FOR DELETE USING (true);

-- Create a storage bucket for the rules documents
INSERT INTO storage.buckets (id, name, public) 
VALUES ('rules_documents', 'rules_documents', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for the bucket
CREATE POLICY "Allow public view rules_documents" 
ON storage.objects FOR SELECT USING (bucket_id = 'rules_documents');

CREATE POLICY "Allow public upload rules_documents" 
ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'rules_documents');

CREATE POLICY "Allow public delete rules_documents" 
ON storage.objects FOR DELETE USING (bucket_id = 'rules_documents');
