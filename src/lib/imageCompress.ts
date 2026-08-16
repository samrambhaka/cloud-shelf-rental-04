/** Client-side image compression using canvas. */

const loadImage = (file: File): Promise<HTMLImageElement> =>
  new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read image"));
    };
    img.src = url;
  });

const toBlob = (canvas: HTMLCanvasElement, quality: number): Promise<Blob | null> =>
  new Promise(resolve => canvas.toBlob(b => resolve(b), "image/jpeg", quality));

/**
 * Compresses an image to be under `targetBytes` (default 100 KB).
 * Progressively lowers quality, then downscales, until it fits.
 */
export const compressImage = async (file: File, targetBytes = 100 * 1024): Promise<File> => {
  if (file.size <= targetBytes) return file;

  const img = await loadImage(file);
  let width = img.naturalWidth;
  let height = img.naturalHeight;

  const MAX_DIM = 1600;
  if (Math.max(width, height) > MAX_DIM) {
    const scale = MAX_DIM / Math.max(width, height);
    width = Math.round(width * scale);
    height = Math.round(height * scale);
  }

  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) return file;

  let best: Blob | null = null;

  for (let attempt = 0; attempt < 8; attempt++) {
    canvas.width = width;
    canvas.height = height;
    ctx.clearRect(0, 0, width, height);
    ctx.drawImage(img, 0, 0, width, height);

    for (const quality of [0.8, 0.6, 0.45, 0.3]) {
      const blob = await toBlob(canvas, quality);
      if (!blob) continue;
      if (!best || blob.size < best.size) best = blob;
      if (blob.size <= targetBytes) {
        return new File([blob], file.name.replace(/\.\w+$/, "") + ".jpg", { type: "image/jpeg" });
      }
    }

    if (Math.min(width, height) <= 200) break;
    width = Math.round(width * 0.75);
    height = Math.round(height * 0.75);
  }

  if (best && best.size < file.size) {
    return new File([best], file.name.replace(/\.\w+$/, "") + ".jpg", { type: "image/jpeg" });
  }
  return file;
};
