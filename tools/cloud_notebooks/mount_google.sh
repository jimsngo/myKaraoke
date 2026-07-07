# 1. Mount Google Drive into the server environment
from google.colab import drive
drive.mount('/content/drive')

# 2. List out the contents of the 'Othercomputers' directory
print("\n🔍 Your Cloud Sync Folder Directory Name:")
!ls -F "/content/drive/Othercomputers/"