"""Convertit l'export de l'app (ios/AlbumData) en WebP : faces/*.jpg, art, packs et backs (*.png, transparence gardée) -> .webp."""
import glob, os, sys
from PIL import Image

root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '../../ios/AlbumData')
for pattern, q in (('faces/*.jpg', 78), ('art/*.png', 85), ('packs/*.png', 85), ('backs/*.png', 85)):
    for f in glob.glob(os.path.join(root, pattern)):
        Image.open(f).save(os.path.splitext(f)[0] + '.webp', 'WEBP', quality=q, method=6)
        os.remove(f)
print('WebP prêt')
