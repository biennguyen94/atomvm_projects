# Init environment setup
## Vscode
```
https://go.microsoft.com/fwlink/?LinkID=760868
sudo apt install ./<file>.deb
```

## Install libs
### gcc, g++ and make
```
sudo apt install build-essential
```

### Others
```
sudo apt install cmake
sudo apt install gperf
sudo apt install zlib1g
sudo apt-get install minicom
sudo apt-get install zlib1g-dev libssl-dev -y
sudo apt-get install libwxbase3.0-0v5 libwxgtk3.0-0v5 libsctp1 -y
```

## Git
```
sudo apt install git-all
git clone https://github.com/biennguyen94/atomvm_basic_projects.git
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
```

## Erlang
```
https://www.erlang-solutions.com/downloads/
sudo apt-get install libwxbase3.0-0v5 libwxgtk3.0-0v5 libsctp1 -y
sudo wget https://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_21.0-1~ubuntu~bionic_amd64.deb
sudo dpkg -i esl-erlang_21.0-1~ubuntu~bionic_amd64.deb
sudo wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
sudo apt-key add erlang_solutions.asc
sudo apt-get install esl-erlang -y
```

## Rebar3
```
cd /tools/
git clone --branch 3.20.0 --recursive https://github.com/erlang/rebar3.git rebar3 
cd rebar3 
./bootstrap
./rebar3 local install
echo "export PATH=\"\$PATH:\$HOME/.cache/rebar3/bin\"" >> ~/.bashrc
```

## minicom
```
sudo apt-get install minicom -y
```

## toolchain
```
sudo apt-get install git wget flex bison gperf python3 python3-pip python3-setuptools libffi-dev libssl-dev -y

mkdir -p /tools/esp
cd /tools/esp
wget https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-1.22.0-80-g6c4433a-5.2.0.tar.gz -O xtensa-toolchain.tar.gz
tar xf xtensa-toolchain.tar.gz
rm xtensa-toolchain.tar.gz

echo "export PATH=\"/tools/esp/xtensa-esp32-elf/bin:\$PATH\"" >> ~/.bashrc

sudo apt-get -qq install wget make libncurses-dev flex bison gperf \
    python python-pip python-setuptools python-serial python-cryptography \
    python-future python-pyparsing python-pyelftools
```

## esp-idf
```
cd /tools/esp
git clone -b v3.2 --recursive https://github.com/espressif/esp-idf.git esp-idf
echo "export IDF_PATH=\"/tools/esp/esp-idf\"" >> ~/.bashrc
python -m pip install --user -r $IDF_PATH/requirements.txt
```

## AtomVM
```
cd /tools/esp
git clone https://github.com/atomvm/AtomVM
git clone https://github.com/atomvm/atomvm_examples.git
git clone https://github.com/biennguyen94/atomvm_basic_projects.git
```

