from PIL import Image
import os

def convert_png_to_jpg(folder_path):
	for filename in os.listdir(folder_path):
		if filename.lower().endswith(".png"):
			png_path = os.path.join(folder_path, filename)
			jpg_filename = os.path.splitext(filename)[0] + ".jpg"
			jpg_path = os.path.join(folder_path, jpg_filename)

			try:
				with Image.open(png_path) as img:
					# 转换为 RGB（因为 JPG 不支持透明通道）
					rgb_img = img.convert("RGB")
					rgb_img.save(jpg_path, "JPEG")
					print(f"Converted: {filename} -> {jpg_filename}")
			except Exception as e:
				print(f"Failed: {filename}, Error: {e}")

if __name__ == "__main__":
	base_dir = os.path.dirname(os.path.abspath(__file__))
	target_dir = os.path.join(base_dir, "../assets/backgrounds")
	convert_png_to_jpg(target_dir)