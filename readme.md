# twrp_device_xiaomi_redmi9a
- dandelion_images_V12.0.16.0.QCDCNXM_20210803.0000.00_10.0_cn
- https://www.bilibili.com/video/BV12P4y1t7ZZ
```
更新软件源
sudo apt update
sudo apt install software-properties-common
添加PPA源
sudo add-apt-repository ppa:deadsnakes/ppa
更新软件源
sudo apt update
安装python3.9
sudo apt install python3.9
添加python3.9
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1
列出python所有版本
sudo update-alternatives --list python
切换python默认版本
sudo update-alternatives --config python
更新pip
sudo apt install python3-pip
python -m pip install --upgrade pip

sudo apt install cpio
pip --verison
pip install twrpdtgen
python -m twrpdtgen -h

mkdir twrpdtgen
mv ./recovery.img ./twrpdtgen
python -m twrpdtgen -d recovery.img
```