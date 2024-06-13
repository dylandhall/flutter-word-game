flutter build web --release --base-href "/wordflower_web/"
copy -Recurse -Force .\build\web\* C:\temp\wordflower_web\
git -C C:\temp\wordflower_web\ add .
git -C C:\temp\wordflower_web\ commit -m "deployment push"
git -C C:\temp\wordflower_web\ push
