REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_wards() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated, service_role;

CREATE TABLE public.promo_banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  title TEXT,
  subtitle TEXT,
  link_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT ON public.promo_banners TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.promo_banners TO authenticated;
GRANT ALL ON public.promo_banners TO service_role;

ALTER TABLE public.promo_banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view live banners" ON public.promo_banners FOR SELECT
USING (
  (is_active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at >= now()))
);
CREATE POLICY "Admins view all banners" ON public.promo_banners FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admins create banners" ON public.promo_banners FOR INSERT TO authenticated
WITH CHECK ((public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin')) AND created_by = auth.uid());
CREATE POLICY "Admins update banners" ON public.promo_banners FOR UPDATE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin') OR (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid()))
WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid()));
CREATE POLICY "Admins delete banners" ON public.promo_banners FOR DELETE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin') OR (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid()));

CREATE TRIGGER update_promo_banners_updated_at
BEFORE UPDATE ON public.promo_banners
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.promo_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  banners_enabled BOOLEAN NOT NULL DEFAULT true,
  rotation_seconds INTEGER NOT NULL DEFAULT 5,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT ON public.promo_config TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.promo_config TO authenticated;
GRANT ALL ON public.promo_config TO service_role;

ALTER TABLE public.promo_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view promo config" ON public.promo_config FOR SELECT USING (true);
CREATE POLICY "Super admin manage promo config" ON public.promo_config FOR ALL TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'))
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE TRIGGER update_promo_config_updated_at
BEFORE UPDATE ON public.promo_config
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

INSERT INTO public.promo_config (banners_enabled, rotation_seconds) VALUES (true, 5);