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