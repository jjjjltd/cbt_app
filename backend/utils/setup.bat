# Windows setup.bat
@echo off
echo Setting up Python backend...
py -3.10-64 -m venv venv
call venv\Scripts\activate
pip install --upgrade pip
pip install https://github.com/jloh02/dlib/releases/download/v19.22/dlib-19.22.99-cp310-cp310-win_amd64.whl
pip install -r requirements.txt
python init_db.py
python update_admin.py
echo Setup complete! Run: python main.py