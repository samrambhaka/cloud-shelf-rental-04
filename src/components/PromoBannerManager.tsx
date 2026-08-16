import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Loader2, Plus, Pencil, Trash2, Megaphone } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import ImageUploadField from "@/components/ImageUploadField";

interface Banner {
  id: string;
  image_url: string;
  title: string | null;
  subtitle: string | null;
  link_url: string | null;
  is_active: boolean;
  starts_at: string | null;
  ends_at: string | null;
  sort_order: number;
  created_by: string | null;
  created_at: string;
}

const emptyForm = {
  image_url: "", title: "", subtitle: "", link_url: "",
  is_active: true, starts_at: "", ends_at: "", sort_order: "0",
};

const toDateInput = (v: string | null) => (v ? v.slice(0, 10) : "");

interface Props {
  /** Super admins can edit every banner and control global banner settings. */
  isSuperAdmin?: boolean;
}

const PromoBannerManager = ({ isSuperAdmin = false }: Props) => {
  const { toast } = useToast();
  const [banners, setBanners] = useState<Banner[]>([]);
  const [creators, setCreators] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Banner | null>(null);
  const [deleting, setDeleting] = useState<Banner | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [config, setConfig] = useState<{ id: string; banners_enabled: boolean; rotation_seconds: number } | null>(null);

  const fetchData = async () => {
    const [bannerRes, cfgRes] = await Promise.all([
      supabase.from("promo_banners").select("*").order("sort_order", { ascending: true }).order("created_at", { ascending: false }),
      supabase.from("promo_config").select("id, banners_enabled, rotation_seconds").limit(1).maybeSingle(),
    ]);

    if (bannerRes.error) {
      toast({ title: "Could not load banners", description: bannerRes.error.message, variant: "destructive" });
    }
    const list = (bannerRes.data || []) as Banner[];
    setBanners(list);
    setConfig(cfgRes.data || null);

    const ids = [...new Set(list.map(b => b.created_by).filter(Boolean))] as string[];
    if (isSuperAdmin && ids.length) {
      const { data } = await supabase.from("profiles").select("id, full_name").in("id", ids);
      setCreators(Object.fromEntries((data || []).map(p => [p.id, p.full_name])));
    }
    setLoading(false);
  };

  useEffect(() => { fetchData(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, []);

  const openAdd = () => { setEditing(null); setForm(emptyForm); setDialogOpen(true); };

  const openEdit = (b: Banner) => {
    setEditing(b);
    setForm({
      image_url: b.image_url,
      title: b.title || "",
      subtitle: b.subtitle || "",
      link_url: b.link_url || "",
      is_active: b.is_active,
      starts_at: toDateInput(b.starts_at),
      ends_at: toDateInput(b.ends_at),
      sort_order: String(b.sort_order),
    });
    setDialogOpen(true);
  };

  const handleSubmit = async () => {
    if (!form.image_url) {
      toast({ title: "Please upload a banner image", variant: "destructive" });
      return;
    }
    setSubmitting(true);
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) { setSubmitting(false); return; }

    const payload = {
      image_url: form.image_url,
      title: form.title.trim() || null,
      subtitle: form.subtitle.trim() || null,
      link_url: form.link_url.trim() || null,
      is_active: form.is_active,
      starts_at: form.starts_at ? new Date(form.starts_at).toISOString() : null,
      ends_at: form.ends_at ? new Date(`${form.ends_at}T23:59:59`).toISOString() : null,
      sort_order: parseInt(form.sort_order || "0", 10) || 0,
    };

    const { error } = editing
      ? await supabase.from("promo_banners").update(payload).eq("id", editing.id)
      : await supabase.from("promo_banners").insert({ ...payload, created_by: session.user.id });

    setSubmitting(false);
    if (error) {
      toast({ title: editing ? "Failed to update banner" : "Failed to create banner", description: error.message, variant: "destructive" });
      return;
    }
    toast({ title: editing ? "Banner updated" : "Banner created" });
    setDialogOpen(false);
    setEditing(null);
    setForm(emptyForm);
    fetchData();
  };

  const toggleActive = async (b: Banner, value: boolean) => {
    const { error } = await supabase.from("promo_banners").update({ is_active: value }).eq("id", b.id);
    if (error) toast({ title: "Could not update banner", description: error.message, variant: "destructive" });
    else fetchData();
  };

  const handleDelete = async () => {
    if (!deleting) return;
    const { error } = await supabase.from("promo_banners").delete().eq("id", deleting.id);
    if (error) toast({ title: "Could not remove banner", description: error.message, variant: "destructive" });
    else { toast({ title: "Banner removed" }); fetchData(); }
    setDeleting(null);
  };

  const updateConfig = async (patch: Partial<{ banners_enabled: boolean; rotation_seconds: number }>) => {
    if (!config) return;
    const next = { ...config, ...patch };
    setConfig(next);
    const { error } = await supabase
      .from("promo_config")
      .update({ banners_enabled: next.banners_enabled, rotation_seconds: next.rotation_seconds })
      .eq("id", config.id);
    if (error) toast({ title: "Could not save settings", description: error.message, variant: "destructive" });
  };

  const statusOf = (b: Banner) => {
    const now = Date.now();
    if (!b.is_active) return { label: "Off", variant: "outline" as const };
    if (b.starts_at && new Date(b.starts_at).getTime() > now) return { label: "Scheduled", variant: "secondary" as const };
    if (b.ends_at && new Date(b.ends_at).getTime() < now) return { label: "Expired", variant: "destructive" as const };
    return { label: "Live", variant: "default" as const };
  };

  if (loading) {
    return <div className="flex justify-center py-12"><Loader2 className="h-6 w-6 animate-spin text-primary" /></div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center gap-3">
        <h2 className="text-lg font-display font-semibold text-foreground">Promotional Banners</h2>
        <Button size="sm" onClick={openAdd}><Plus className="h-4 w-4 mr-1" /> Add Banner</Button>
      </div>

      {isSuperAdmin && config && (
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base font-display">Banner Settings</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="flex items-center gap-3">
              <Switch
                id="banners-enabled"
                checked={config.banners_enabled}
                onCheckedChange={v => updateConfig({ banners_enabled: v })}
              />
              <Label htmlFor="banners-enabled" className="font-body">Show banners on Browse</Label>
            </div>
            <div className="flex items-center gap-2">
              <Label htmlFor="rotation" className="font-body whitespace-nowrap">Rotate every</Label>
              <Input
                id="rotation"
                type="number"
                min={2}
                className="w-20"
                value={config.rotation_seconds}
                onChange={e => setConfig({ ...config, rotation_seconds: Number(e.target.value) })}
                onBlur={e => updateConfig({ rotation_seconds: Math.max(2, Number(e.target.value) || 5) })}
              />
              <span className="text-sm text-muted-foreground font-body">seconds</span>
            </div>
          </CardContent>
        </Card>
      )}

      {banners.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center py-12 text-center">
            <Megaphone className="h-12 w-12 text-muted-foreground mb-3" />
            <p className="text-muted-foreground font-body">No banners yet. Add your first promotion!</p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3">
          {banners.map(b => {
            const status = statusOf(b);
            return (
              <Card key={b.id}>
                <CardContent className="p-3 flex items-center gap-3">
                  <img src={b.image_url} alt={b.title || "Banner"} className="w-16 h-20 rounded-md object-cover border border-border shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-display font-medium text-foreground truncate">{b.title || "Untitled banner"}</p>
                    {b.subtitle && <p className="text-xs text-muted-foreground font-body truncate">{b.subtitle}</p>}
                    <p className="text-[11px] text-muted-foreground font-body truncate mt-0.5">
                      {b.link_url || "No link"} · order {b.sort_order}
                      {b.starts_at || b.ends_at ? ` · ${toDateInput(b.starts_at) || "—"} → ${toDateInput(b.ends_at) || "—"}` : ""}
                      {isSuperAdmin && b.created_by ? ` · by ${creators[b.created_by] || "Unknown"}` : ""}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <Badge variant={status.variant}>{status.label}</Badge>
                    <Switch checked={b.is_active} onCheckedChange={v => toggleActive(b, v)} />
                    <Button size="sm" variant="ghost" onClick={() => openEdit(b)}><Pencil className="h-4 w-4" /></Button>
                    <Button size="sm" variant="ghost" onClick={() => setDeleting(b)}><Trash2 className="h-4 w-4 text-destructive" /></Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      <Dialog open={dialogOpen} onOpenChange={open => { if (!open) setEditing(null); setDialogOpen(open); }}>
        <DialogContent className="max-w-md max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="font-display">{editing ? "Edit Banner" : "Add Banner"}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <ImageUploadField label="Banner image *" value={form.image_url} onChange={v => setForm(f => ({ ...f, image_url: v }))} />
            <div>
              <Label>Title</Label>
              <Input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>
            <div>
              <Label>Subtitle</Label>
              <Textarea value={form.subtitle} onChange={e => setForm(f => ({ ...f, subtitle: e.target.value }))} />
            </div>
            <div>
              <Label>Link (optional)</Label>
              <Input
                placeholder="/browse or https://example.com"
                value={form.link_url}
                onChange={e => setForm(f => ({ ...f, link_url: e.target.value }))}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>Start date</Label>
                <Input type="date" value={form.starts_at} onChange={e => setForm(f => ({ ...f, starts_at: e.target.value }))} />
              </div>
              <div>
                <Label>End date</Label>
                <Input type="date" value={form.ends_at} onChange={e => setForm(f => ({ ...f, ends_at: e.target.value }))} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3 items-end">
              <div>
                <Label>Display order</Label>
                <Input type="number" value={form.sort_order} onChange={e => setForm(f => ({ ...f, sort_order: e.target.value }))} />
              </div>
              <div className="flex items-center gap-2 pb-2">
                <Switch checked={form.is_active} onCheckedChange={v => setForm(f => ({ ...f, is_active: v }))} />
                <Label className="font-body">Active</Label>
              </div>
            </div>
            <Button onClick={handleSubmit} disabled={submitting} className="w-full">
              {submitting ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : null}
              {editing ? "Save Changes" : "Create Banner"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      <AlertDialog open={!!deleting} onOpenChange={open => !open && setDeleting(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remove Banner</AlertDialogTitle>
            <AlertDialogDescription>
              This will permanently delete "{deleting?.title || "this banner"}".
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete}>Remove</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default PromoBannerManager;
