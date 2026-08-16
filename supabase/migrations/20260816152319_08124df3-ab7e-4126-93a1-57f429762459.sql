-- ENUMS
CREATE TYPE public.app_role AS ENUM ('super_admin', 'admin', 'owner', 'customer', 'delivery');
CREATE TYPE public.order_status AS ENUM ('pending', 'confirmed', 'delivery_booked', 'picked_up', 'in_transit', 'delivered', 'return_pending', 'returned', 'cancelled');
CREATE TYPE public.payment_method AS ENUM ('prepaid', 'cash_on_delivery');
CREATE TYPE public.payment_status AS ENUM ('pending', 'submitted', 'verified', 'collected', 'refunded');
CREATE TYPE public.settlement_status AS ENUM ('pending', 'settled');
CREATE TYPE public.item_status AS ENUM ('pending_approval', 'active', 'inactive', 'rejected');

-- TABLES
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  avatar_url TEXT,
  date_of_birth DATE,
  delivery_address TEXT,
  panchayath_id UUID,
  ward_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  UNIQUE(user_id, role)
);

CREATE TABLE public.states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  state_id UUID NOT NULL REFERENCES public.states(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(name, state_id)
);

CREATE TABLE public.panchayaths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  district_id UUID NOT NULL REFERENCES public.districts(id) ON DELETE CASCADE,
  ward_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(name, district_id)
);

CREATE TABLE public.wards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ward_number INT NOT NULL,
  panchayath_id UUID NOT NULL REFERENCES public.panchayaths(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(ward_number, panchayath_id)
);

ALTER TABLE public.profiles ADD CONSTRAINT profiles_panchayath_fk FOREIGN KEY (panchayath_id) REFERENCES public.panchayaths(id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_ward_fk FOREIGN KEY (ward_id) REFERENCES public.wards(id);

CREATE TABLE public.areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.area_panchayaths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  panchayath_id UUID NOT NULL REFERENCES public.panchayaths(id) ON DELETE CASCADE,
  UNIQUE(area_id, panchayath_id)
);

CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  commission_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.categories(id),
  name TEXT NOT NULL,
  description TEXT,
  owner_price NUMERIC(10,2) NOT NULL,
  image_urls TEXT[] DEFAULT '{}',
  video_url TEXT,
  payment_type TEXT NOT NULL DEFAULT 'cash_on_delivery' CHECK (payment_type IN ('prepaid', 'cash_on_delivery')),
  status item_status NOT NULL DEFAULT 'pending_approval',
  area_id UUID REFERENCES public.areas(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.delivery_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fixed_charge NUMERIC(10,2) NOT NULL DEFAULT 50,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  item_id UUID NOT NULL REFERENCES public.items(id),
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  delivery_staff_id UUID REFERENCES auth.users(id),
  owner_price NUMERIC(10,2) NOT NULL,
  commission_amount NUMERIC(10,2) NOT NULL,
  delivery_charge NUMERIC(10,2) NOT NULL,
  total_amount NUMERIC(10,2) NOT NULL,
  payment_method payment_method NOT NULL DEFAULT 'cash_on_delivery',
  status order_status NOT NULL DEFAULT 'pending',
  delivery_address TEXT,
  ward_id UUID REFERENCES public.wards(id),
  start_date DATE,
  end_date DATE,
  rental_days INTEGER NOT NULL DEFAULT 1,
  booked_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  method payment_method NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  verified_by UUID REFERENCES auth.users(id),
  collected_by UUID REFERENCES auth.users(id),
  collected_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  balance NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_earned NUMERIC(10,2) NOT NULL DEFAULT 0,
  pending_settlement NUMERIC(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC(10,2) NOT NULL,
  status settlement_status NOT NULL DEFAULT 'pending',
  settled_by UUID REFERENCES auth.users(id),
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.admin_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  UNIQUE(admin_id, area_id)
);

CREATE TABLE public.delivery_staff_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  UNIQUE(staff_id, area_id)
);

CREATE TABLE public.owner_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  UNIQUE(owner_id, area_id)
);

CREATE TABLE public.delivery_staff_wards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  panchayath_id UUID NOT NULL REFERENCES public.panchayaths(id) ON DELETE CASCADE,
  ward_id UUID NOT NULL REFERENCES public.wards(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (staff_id, ward_id)
);

CREATE TABLE public.vendor_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  panchayath_id UUID REFERENCES public.panchayaths(id),
  ward_id UUID REFERENCES public.wards(id),
  status TEXT NOT NULL DEFAULT 'pending',
  requested_role public.app_role NOT NULL DEFAULT 'owner',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);
CREATE INDEX vendor_applications_requested_role_idx ON public.vendor_applications (requested_role, status);

CREATE TABLE public.storage_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL DEFAULT 'supabase',
  cloudinary_cloud_name TEXT,
  cloudinary_upload_preset TEXT,
  folder TEXT,
  fallback_to_supabase BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- GRANTS
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles, public.user_roles, public.states, public.districts, public.panchayaths, public.wards, public.areas, public.area_panchayaths, public.categories, public.items, public.delivery_config, public.orders, public.payments, public.wallets, public.settlements, public.admin_areas, public.delivery_staff_areas, public.owner_areas, public.delivery_staff_wards, public.vendor_applications, public.storage_config TO authenticated;
GRANT ALL ON public.profiles, public.user_roles, public.states, public.districts, public.panchayaths, public.wards, public.areas, public.area_panchayaths, public.categories, public.items, public.delivery_config, public.orders, public.payments, public.wallets, public.settlements, public.admin_areas, public.delivery_staff_areas, public.owner_areas, public.delivery_staff_wards, public.vendor_applications, public.storage_config TO service_role;
GRANT SELECT ON public.items, public.categories, public.delivery_config, public.storage_config, public.states, public.districts, public.panchayaths, public.wards, public.areas, public.area_panchayaths TO anon;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, mobile)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), COALESCE(NEW.raw_user_meta_data->>'mobile', ''));
  IF COALESCE(NEW.raw_user_meta_data->>'role', '') = 'customer' THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'customer');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.generate_wards()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.ward_count > 0 AND (OLD.ward_count IS NULL OR NEW.ward_count <> OLD.ward_count) THEN
    DELETE FROM public.wards WHERE panchayath_id = NEW.id;
    FOR i IN 1..NEW.ward_count LOOP
      INSERT INTO public.wards (ward_number, panchayath_id) VALUES (i, NEW.id);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_panchayath_ward_count_change
  AFTER INSERT OR UPDATE OF ward_count ON public.panchayaths
  FOR EACH ROW EXECUTE FUNCTION public.generate_wards();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_storage_config_updated_at
BEFORE UPDATE ON public.storage_config
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid());
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Admins manage roles" ON public.user_roles FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.states ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read states" ON public.states FOR SELECT USING (true);
CREATE POLICY "Super admin manage states" ON public.states FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.districts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read districts" ON public.districts FOR SELECT USING (true);
CREATE POLICY "Super admin manage districts" ON public.districts FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.panchayaths ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read panchayaths" ON public.panchayaths FOR SELECT USING (true);
CREATE POLICY "Super admin manage panchayaths" ON public.panchayaths FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.wards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read wards" ON public.wards FOR SELECT USING (true);

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read areas" ON public.areas FOR SELECT USING (true);
CREATE POLICY "Super admin manage areas" ON public.areas FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.area_panchayaths ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read area_panchayaths" ON public.area_panchayaths FOR SELECT USING (true);
CREATE POLICY "Super admin manage area_panchayaths" ON public.area_panchayaths FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Super admin manage categories" ON public.categories FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view active items" ON public.items FOR SELECT TO authenticated USING (status = 'active' OR owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Anon can view active items" ON public.items FOR SELECT TO anon USING (status = 'active'::item_status);
CREATE POLICY "Owners can insert items" ON public.items FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Admins can insert items" ON public.items FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Owners can update own items" ON public.items FOR UPDATE TO authenticated USING (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

ALTER TABLE public.delivery_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read delivery config" ON public.delivery_config FOR SELECT USING (true);
CREATE POLICY "Super admin manage delivery config" ON public.delivery_config FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Customers view own orders" ON public.orders FOR SELECT TO authenticated USING (customer_id = auth.uid() OR owner_id = auth.uid() OR delivery_staff_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Delivery staff view open orders in their wards" ON public.orders FOR SELECT TO authenticated USING (
  delivery_staff_id IS NULL AND status = 'confirmed' AND EXISTS (
    SELECT 1 FROM public.delivery_staff_wards dsw WHERE dsw.staff_id = auth.uid() AND dsw.ward_id = orders.ward_id
  )
);
CREATE POLICY "Customers create orders" ON public.orders FOR INSERT TO authenticated WITH CHECK (customer_id = auth.uid());
CREATE POLICY "Authorized users update orders" ON public.orders FOR UPDATE TO authenticated USING (owner_id = auth.uid() OR delivery_staff_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View payments" ON public.payments FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Delivery staff view own collections" ON public.payments FOR SELECT TO authenticated USING (collected_by = auth.uid());
CREATE POLICY "Create payments" ON public.payments FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_id AND (orders.customer_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'delivery')))
);
CREATE POLICY "Update payments" ON public.payments FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Delivery staff submit own collections" ON public.payments FOR UPDATE TO authenticated USING (collected_by = auth.uid()) WITH CHECK (collected_by = auth.uid());

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own wallet" ON public.wallets FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "System manages wallets" ON public.wallets FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own settlements" ON public.settlements FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admin manage settlements" ON public.settlements FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.admin_areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View admin areas" ON public.admin_areas FOR SELECT TO authenticated USING (admin_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Super admin manage admin areas" ON public.admin_areas FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.delivery_staff_areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View delivery areas" ON public.delivery_staff_areas FOR SELECT TO authenticated USING (staff_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admin manage delivery areas" ON public.delivery_staff_areas FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.owner_areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View owner areas" ON public.owner_areas FOR SELECT TO authenticated USING (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admin manage owner areas" ON public.owner_areas FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.delivery_staff_wards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "View delivery staff wards" ON public.delivery_staff_wards FOR SELECT TO authenticated USING (staff_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admins manage delivery staff wards" ON public.delivery_staff_wards FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin')) WITH CHECK (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.vendor_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users create own vendor application" ON public.vendor_applications FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "View own or admin vendor applications" ON public.vendor_applications FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admins update vendor applications" ON public.vendor_applications FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admins delete vendor applications" ON public.vendor_applications FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

ALTER TABLE public.storage_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view storage config" ON public.storage_config FOR SELECT USING (true);
CREATE POLICY "Admins can insert storage config" ON public.storage_config FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Admins can update storage config" ON public.storage_config FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin')) WITH CHECK (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'super_admin'));

-- SEED DATA
INSERT INTO public.delivery_config (fixed_charge) VALUES (50);
INSERT INTO public.storage_config (provider) VALUES ('supabase');
INSERT INTO public.categories (name, commission_rate) VALUES
  ('Dress', 15), ('Ornaments', 20), ('Electronics', 10), ('Tools', 10), ('Furniture', 12);
INSERT INTO public.states (name) VALUES ('Kerala');
INSERT INTO public.districts (name, state_id)
SELECT d.name, s.id FROM (VALUES ('Thrissur'), ('Ernakulam'), ('Palakkad')) AS d(name), public.states s WHERE s.name = 'Kerala';
INSERT INTO public.panchayaths (name, district_id, ward_count)
SELECT p.name, d.id, p.wc FROM (VALUES
  ('Kuttanellur', 'Thrissur', 25), ('Ollur', 'Thrissur', 20), ('Nadathara', 'Thrissur', 18),
  ('Koorkenchery', 'Thrissur', 22), ('Ayyanthole', 'Thrissur', 19), ('Kakkanad', 'Ernakulam', 30),
  ('Thrikkakara', 'Ernakulam', 28), ('Palakkad Town', 'Palakkad', 35)
) AS p(name, dist, wc) JOIN public.districts d ON d.name = p.dist;
INSERT INTO public.areas (name) VALUES ('Thrissur East'), ('Thrissur West'), ('Kochi Metro'), ('Palakkad Central');
INSERT INTO public.area_panchayaths (area_id, panchayath_id)
SELECT a.id, p.id FROM public.areas a, public.panchayaths p
WHERE (a.name = 'Thrissur East' AND p.name IN ('Kuttanellur', 'Ollur', 'Nadathara', 'Koorkenchery'))
   OR (a.name = 'Thrissur West' AND p.name = 'Ayyanthole')
   OR (a.name = 'Kochi Metro' AND p.name IN ('Kakkanad', 'Thrikkakara'))
   OR (a.name = 'Palakkad Central' AND p.name = 'Palakkad Town');