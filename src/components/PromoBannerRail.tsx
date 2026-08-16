import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";

interface Banner {
  id: string;
  image_url: string;
  title: string | null;
  subtitle: string | null;
  link_url: string | null;
}

/** Auto-rotating promotional banner rail: vertical on wide screens, compact strip on mobile. */
const PromoBannerRail = () => {
  const navigate = useNavigate();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [index, setIndex] = useState(0);
  const [rotation, setRotation] = useState(5);
  const [enabled, setEnabled] = useState(true);

  useEffect(() => {
    const load = async () => {
      const nowIso = new Date().toISOString();
      const [cfgRes, bannerRes] = await Promise.all([
        supabase.from("promo_config").select("banners_enabled, rotation_seconds").limit(1).maybeSingle(),
        supabase
          .from("promo_banners")
          .select("id, image_url, title, subtitle, link_url, starts_at, ends_at, is_active, sort_order")
          .eq("is_active", true)
          .order("sort_order", { ascending: true })
          .order("created_at", { ascending: false }),
      ]);

      if (cfgRes.data) {
        setEnabled(cfgRes.data.banners_enabled);
        setRotation(Math.max(2, cfgRes.data.rotation_seconds || 5));
      }

      const live = (bannerRes.data || []).filter(
        b => (!b.starts_at || b.starts_at <= nowIso) && (!b.ends_at || b.ends_at >= nowIso),
      );
      setBanners(live as Banner[]);
    };
    load();
  }, []);

  const visible = useMemo(() => (enabled ? banners : []), [enabled, banners]);

  useEffect(() => {
    if (visible.length < 2) return;
    const t = setInterval(() => setIndex(i => (i + 1) % visible.length), rotation * 1000);
    return () => clearInterval(t);
  }, [visible.length, rotation]);

  if (visible.length === 0) return null;

  const openLink = (url: string | null) => {
    if (!url) return;
    if (url.startsWith("/")) navigate(url);
    else window.open(url, "_blank", "noopener,noreferrer");
  };

  return (
    <aside
      aria-label="Promotions"
      className="w-full lg:w-56 xl:w-64 shrink-0 mb-4 lg:mb-0"
    >
      <div className="lg:sticky lg:top-4 relative rounded-lg overflow-hidden border border-border bg-card h-36 lg:h-[520px]">
        {visible.map((banner, i) => (
          <button
            key={banner.id}
            type="button"
            onClick={() => openLink(banner.link_url)}
            aria-hidden={i !== index}
            tabIndex={i === index ? 0 : -1}
            className={`absolute inset-0 w-full h-full text-left transition-opacity duration-700 ${
              i === index ? "opacity-100" : "opacity-0 pointer-events-none"
            } ${banner.link_url ? "cursor-pointer" : "cursor-default"}`}
          >
            <img
              src={banner.image_url}
              alt={banner.title || "Promotion"}
              loading="lazy"
              className="w-full h-full object-cover"
            />
            {(banner.title || banner.subtitle) && (
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-foreground/80 to-transparent p-3">
                {banner.title && (
                  <p className="font-display font-semibold text-sm text-background leading-tight">{banner.title}</p>
                )}
                {banner.subtitle && (
                  <p className="font-body text-[11px] text-background/85 mt-0.5 line-clamp-2">{banner.subtitle}</p>
                )}
              </div>
            )}
          </button>
        ))}

        {visible.length > 1 && (
          <div className="absolute bottom-2 right-2 flex gap-1.5">
            {visible.map((b, i) => (
              <button
                key={b.id}
                type="button"
                aria-label={`Show promotion ${i + 1}`}
                onClick={() => setIndex(i)}
                className={`h-1.5 rounded-full transition-all ${
                  i === index ? "w-4 bg-background" : "w-1.5 bg-background/60"
                }`}
              />
            ))}
          </div>
        )}
      </div>
    </aside>
  );
};

export default PromoBannerRail;
