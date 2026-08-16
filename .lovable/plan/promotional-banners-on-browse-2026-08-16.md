# Promotional Banners on Browse

Add a vertical, auto-rotating ("flash") promo banner to the Browse page, with content managed by Admin and full control for Super Admin.

## What the user sees

**Browse page (`/browse`)**
- A tall vertical banner panel beside the item grid on wide screens; on mobile it collapses into a compact full-width banner strip above the grid.
- Banners auto-rotate every few seconds with a fade/slide transition; dots let you jump between them.
- Each banner is an image with optional title, subtitle and link — clicking opens the link (internal route or external URL).
- Only active banners inside their schedule window are shown; if none are active, the panel is hidden entirely and the grid takes full width.

**Admin (`/admin/promotions`)**
- New "Promotions" section: list of banners with image thumbnail, title, link, status, schedule and display order.
- Create/edit dialog with image upload (uses the existing uploader with 1MB→auto-compress), title, subtitle, link URL, start/end date, active toggle, sort order.
- Admins can delete their own banners and toggle active state.

**Super Admin (`/superadmin/promotions`)**
- Same management screen plus: sees banners from all admins with the creator name, can edit/delete any banner, and can globally enable/disable the banner panel and set the rotation interval.

## Technical notes

- New table `public.promo_banners`: `id`, `image_url`, `title`, `subtitle`, `link_url`, `is_active`, `starts_at`, `ends_at`, `sort_order`, `created_by`, timestamps.
  - GRANTs: `select` to `anon` + `authenticated`; full CRUD to `authenticated`; `all` to `service_role`.
  - RLS: public read limited to active + in-schedule rows; insert/update/delete restricted to `has_role(auth.uid(),'admin')` or `'super_admin'` (super admin unrestricted, admin limited to own rows for delete).
- New table `public.promo_config` (single row): `banners_enabled`, `rotation_seconds`; public read, super-admin write.
- New component `src/components/PromoBannerRail.tsx` handling fetch, rotation timer, and the responsive vertical/horizontal layout.
- `src/pages/BrowseItems.tsx`: wrap existing grid in a flex row and mount the rail; no changes to item fetching/filtering logic.
- New pages `src/pages/admin/AdminPromotions.tsx` and `src/pages/superadmin/SAPromotions.tsx`, reusing a shared form; registered in the nav arrays and route switches of `AdminDashboard.tsx` and `SuperAdminDashboard.tsx`.
- Image uploads reuse `ImageUploadField` / `uploadImage`, so Cloudinary-or-storage config and compression apply automatically.
