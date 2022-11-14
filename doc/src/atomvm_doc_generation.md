# Doc genaration

## Sphinx installation
```
python3 -m pip install sphinx
python3 -m pip install myst-parser
python3 -m pip install sphinx-rtd-theme
```

## HTML genaration
```
cd /tools/atomvm_basic_projects
mkdir build
cd build
cmake ..
make sphinx-html
```

## Upload html to webserver
```
apt install screen
apt install vim
cd /tools/atomvm_basic_projects/build/doc/html/
screen -d -m python3 -m http.server 7777
top -n 1 | pgrep screen
kill -9 `top -n 1 | pgrep screen`
```

## To use local html folder instead of container
```
docker run --name bien_atomvm --net host -it --mount src="$(pwd)",target=/atomvm_doc,type=bind biennguyen94/atomvm:ubuntu20_04_v1
```