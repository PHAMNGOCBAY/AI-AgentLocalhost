@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo.
echo  ╔═══════════════════════════════════════════════════╗
echo  ║   Ollama Smart Router - Full Installer v4.1       ║
echo  ║   Python + Ollama + Models + MCP + Extensions     ║
echo  ╚═══════════════════════════════════════════════════╝
echo.

set "GEMINI_DIR=%USERPROFILE%\.gemini"
set "INSTALL_DIR=%~dp0"
set "TEMP_DIR=%TEMP%\ollama-setup"

:: ============================================================
:: STEP 0: Antigravity IDE
:: ============================================================
echo  [1/9] Checking Antigravity IDE...
where antigravity-ide >nul 2>&1
if errorlevel 1 (
    if not exist "%LOCALAPPDATA%\Programs\Antigravity IDE\Antigravity IDE.exe" (
        echo    Antigravity IDE not found. Installing via winget...
        winget install Google.AntigravityIDE --accept-source-agreements --accept-package-agreements
        if errorlevel 1 (
            echo    ERROR: Failed to install Antigravity IDE. Install manually from Google Cloud.
            pause & exit /b 1
        )
        echo    OK - Antigravity IDE installed
    ) else (
        echo    OK - Antigravity IDE found
    )
) else (
    echo    OK - Antigravity IDE found
)

:: ============================================================
:: STEP 1: Python
:: ============================================================
echo  [2/9] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo    Python not found. Downloading Python 3.12...
    if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe' -OutFile '%TEMP_DIR%\python_installer.exe'"
    if errorlevel 1 (
        echo    ERROR: Download failed. Install from python.org
        pause & exit /b 1
    )
    echo    Installing Python 3.12...
    "%TEMP_DIR%\python_installer.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_pip=1
    if errorlevel 1 (
        echo    ERROR: Install failed. Run manually: %TEMP_DIR%\python_installer.exe
        pause & exit /b 1
    )
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Python\Python312;%USERPROFILE%\AppData\Local\Programs\Python\Python312\Scripts;%PATH%"
    echo    OK - Python installed
) else (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo    OK - %%i
)

for /f "tokens=*" %%i in ('where python 2^>nul') do (
    set "PYTHON_PATH=%%i"
    goto :GOT_PYTHON
)
:GOT_PYTHON

:: ============================================================
:: STEP 2: Ollama
:: ============================================================
echo.
echo  [3/9] Checking Ollama...
ollama --version >nul 2>&1
if errorlevel 1 (
    echo    Ollama not found. Downloading...
    if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
    powershell -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '%TEMP_DIR%\OllamaSetup.exe'"
    if errorlevel 1 (
        echo    ERROR: Download failed. Install from ollama.com
        pause & exit /b 1
    )
    echo    Installing Ollama...
    start /wait "" "%TEMP_DIR%\OllamaSetup.exe" /VERYSILENT /NORESTART
    set "PATH=%USERPROFILE%\AppData\Local\Programs\Ollama;%PATH%"
    timeout /t 5 /nobreak >nul
    ollama --version >nul 2>&1
    if errorlevel 1 (
        echo    Installed but needs restart. Restart PC then re-run install.bat
        pause & exit /b 1
    )
    echo    OK - Ollama installed
) else (
    for /f "tokens=*" %%i in ('ollama --version 2^>^&1') do echo    OK - %%i
)

:: ============================================================
:: STEP 3: MCP server script
:: ============================================================
echo.
echo  [4/9] Installing MCP server script...
if not exist "%GEMINI_DIR%\antigravity" mkdir "%GEMINI_DIR%\antigravity"
copy /Y "%INSTALL_DIR%ollama_mcp.py" "%GEMINI_DIR%\antigravity\ollama_mcp.py" >nul
echo    OK - ollama_mcp.py

:: ============================================================
:: STEP 4: Skills
:: ============================================================
echo.
echo  [5/9] Installing skills...
if not exist "%GEMINI_DIR%\config\skills\ollama-models" mkdir "%GEMINI_DIR%\config\skills\ollama-models"
if not exist "%GEMINI_DIR%\config\skills\ollama-mcp-troubleshooting" mkdir "%GEMINI_DIR%\config\skills\ollama-mcp-troubleshooting"
if not exist "%GEMINI_DIR%\config\skills\ollama" mkdir "%GEMINI_DIR%\config\skills\ollama"
copy /Y "%INSTALL_DIR%skills\ollama-models\SKILL.md" "%GEMINI_DIR%\config\skills\ollama-models\SKILL.md" >nul
copy /Y "%INSTALL_DIR%skills\ollama-mcp-troubleshooting\SKILL.md" "%GEMINI_DIR%\config\skills\ollama-mcp-troubleshooting\SKILL.md" >nul
copy /Y "%INSTALL_DIR%skills\ollama\SKILL.md" "%GEMINI_DIR%\config\skills\ollama\SKILL.md" >nul
echo    OK - 3 skills installed

:: ============================================================
:: STEP 5: MCP config
:: ============================================================
echo.
echo  [6/9] Configuring MCP...
set "MCP_CONFIG=%GEMINI_DIR%\config\mcp_config.json"
set "PY_FWD=%PYTHON_PATH:\=/%"
set "SCRIPT_FWD=%GEMINI_DIR:\=/%/antigravity/ollama_mcp.py"

if not exist "%GEMINI_DIR%\config" mkdir "%GEMINI_DIR%\config"

if exist "%MCP_CONFIG%" (
    findstr /C:"ollama" "%MCP_CONFIG%" >nul 2>&1
    if errorlevel 1 (
        echo    WARNING: mcp_config.json exists but no ollama entry.
        echo    Add manually - see mcp_config_sample.json
    ) else (
        echo    OK - ollama entry found
    )
) else (
    echo {"mcpServers":{"ollama":{"args":["!SCRIPT_FWD!"],"command":"!PY_FWD!"}}} > "%MCP_CONFIG%"
    powershell -Command "(Get-Content '%MCP_CONFIG%') | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Set-Content '%MCP_CONFIG%' -Encoding UTF8" 2>nul
    echo    OK - Created mcp_config.json
)

:: ============================================================
:: STEP 6: Pull Ollama models
:: ============================================================
echo.
echo  [7/9] Ollama models
echo.
echo    ┌──────────────────────────────────────────┐
echo    │  gemma4:e4b                  ~  9.6 GB   │
echo    │  gemma4:26b                  ~ 17   GB   │
echo    │  qwen2.5-coder:32b          ~ 20   GB   │
echo    │  nemotron-3.5-lightning      ~ 25   GB   │
echo    │                              ──────────  │
echo    │  Total                       ~ 71.6 GB   │
echo    └──────────────────────────────────────────┘
echo.

:: Check which models already exist
echo    Checking existing models...
set "NEED_E4B=1"
set "NEED_26B=1"
set "NEED_QWEN=1"
set "NEED_NEMO=1"

for /f "tokens=1" %%m in ('ollama list 2^>nul ^| findstr /V "NAME"') do (
    if "%%m"=="gemma4:e4b" set "NEED_E4B=0"
    if "%%m"=="gemma4:26b" set "NEED_26B=0"
    if "%%m"=="qwen2.5-coder:32b" set "NEED_QWEN=0"
    if "%%m"=="nemotron-3.5-lightning:latest" set "NEED_NEMO=0"
)

if "%NEED_E4B%%NEED_26B%%NEED_QWEN%%NEED_NEMO%"=="0000" (
    echo    All models already installed!
    goto :EXTENSIONS
)

set /p PULL_CHOICE="    Pull models? (A=all / S=select / N=skip): "

if /i "%PULL_CHOICE%"=="N" goto :EXTENSIONS
if /i "%PULL_CHOICE%"=="S" goto :SELECT_MODELS

:: Pull all missing
if "%NEED_E4B%"=="1" (
    echo.
    echo    Pulling gemma4:e4b...
    ollama pull gemma4:e4b
)
if "%NEED_26B%"=="1" (
    echo.
    echo    Pulling gemma4:26b...
    ollama pull gemma4:26b
)
if "%NEED_QWEN%"=="1" (
    echo.
    echo    Pulling qwen2.5-coder:32b...
    ollama pull qwen2.5-coder:32b
)
if "%NEED_NEMO%"=="1" (
    echo.
    echo    Pulling nemotron-3.5-lightning...
    ollama pull nemotron-3.5-lightning
)
goto :EXTENSIONS

:SELECT_MODELS
echo.
if "%NEED_E4B%"=="1" (
    set /p P1="    Pull gemma4:e4b (9.6 GB)? (Y/N): "
    if /i "!P1!"=="Y" ollama pull gemma4:e4b
) else echo    gemma4:e4b - already installed

if "%NEED_26B%"=="1" (
    set /p P2="    Pull gemma4:26b (17 GB)? (Y/N): "
    if /i "!P2!"=="Y" ollama pull gemma4:26b
) else echo    gemma4:26b - already installed

if "%NEED_QWEN%"=="1" (
    set /p P3="    Pull qwen2.5-coder:32b (20 GB)? (Y/N): "
    if /i "!P3!"=="Y" ollama pull qwen2.5-coder:32b
) else echo    qwen2.5-coder:32b - already installed

if "%NEED_NEMO%"=="1" (
    set /p P4="    Pull nemotron-3.5-lightning (25 GB)? (Y/N): "
    if /i "!P4!"=="Y" ollama pull nemotron-3.5-lightning
) else echo    nemotron-3.5-lightning - already installed

:: ============================================================
:: STEP 7: Python Libraries
:: ============================================================
:PYLIBS
echo.
echo  [8/9] Python Libraries (10 categories)
echo.
echo    ┌──────────────────────────────────────────────────┐
echo    │  BIM/IFC ........... ifcopenshell, ezdxf, cjio   │
echo    │  Geotech/Struct .... openseespy, gmsh, xslope    │
echo    │  3D Visualization .. pyvista, vtk, open3d, vedo  │
echo    │  Data Science ...... numpy, pandas, scipy, sklearn│
echo    │  AI/NLP ............ torch, transformers, chromadb│
echo    │  Document .......... docx, openpyxl, pymupdf     │
echo    │  Web/API ........... flask, streamlit, mcp       │
echo    │  GIS/Mapping ....... pyproj, shapely, folium     │
echo    │  Jupyter ........... jupyter, jupyterlab, notebook│
echo    │  Utilities ......... pydantic, rich, click, Pillow│
echo    └──────────────────────────────────────────────────┘
echo.

set /p PY_CHOICE="    Install Python libraries? (A=all / S=select / N=skip): "

if /i "%PY_CHOICE%"=="N" goto :EXTENSIONS
if /i "%PY_CHOICE%"=="S" goto :SELECT_PY

:: Install all from requirements.txt
echo.
echo    Installing all libraries from requirements.txt...
echo    (This may take 10-30 minutes depending on your internet)
echo.
pip install -r "%INSTALL_DIR%requirements.txt" --quiet
if errorlevel 1 (
    echo    WARNING: Some packages may have failed. Check output above.
) else (
    echo    All libraries installed!
)
goto :EXTENSIONS

:SELECT_PY
echo.

set /p PY1="    [BIM/IFC] ifcopenshell, ezdxf, cjio, bcf-client? (Y/N): "
if /i "%PY1%"=="Y" (
    echo      Installing BIM/IFC libraries...
    pip install ifcopenshell ezdxf cjio bcf-client bsdd ifc4d ifc5d ifccityjson ifcclash ifccsv ifcdiff ifcedit ifcfm ifcpatch ifcquery ifctester --quiet
)

set /p PY2="    [Geotech/Struct] openseespy, gmsh, PyNiteFEA, xslope? (Y/N): "
if /i "%PY2%"=="Y" (
    echo      Installing Geotechnical/Structural libraries...
    pip install openseespy PyNiteFEA xslope geotech-references geotech-staff-engineer gmsh midas_civil --quiet
)

set /p PY3="    [3D Visualization] pyvista, vtk, open3d, mayavi, vedo? (Y/N): "
if /i "%PY3%"=="Y" (
    echo      Installing 3D Visualization libraries...
    pip install pyvista vtk open3d mayavi vedo trimesh meshio --quiet
)

set /p PY4="    [Data Science] numpy, pandas, scipy, sklearn, matplotlib? (Y/N): "
if /i "%PY4%"=="Y" (
    echo      Installing Data Science libraries...
    pip install numpy pandas scipy scikit-learn matplotlib seaborn plotly polars statsmodels sympy bokeh --quiet
)

set /p PY5="    [AI/NLP] torch, transformers, chromadb, sentence-transformers? (Y/N): "
if /i "%PY5%"=="Y" (
    echo      Installing AI/NLP libraries...
    echo      NOTE: PyTorch with CUDA ~2.5GB download
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --quiet
    pip install transformers sentence-transformers huggingface_hub chromadb onnxruntime accelerate tokenizers --quiet
)

set /p PY6="    [Document] python-docx, openpyxl, pymupdf, reportlab? (Y/N): "
if /i "%PY6%"=="Y" (
    echo      Installing Document Processing libraries...
    pip install python-docx openpyxl python-pptx pymupdf pymupdf4llm pdfplumber pypdf reportlab fpdf2 xhtml2pdf xlsxwriter xlrd docxtpl mammoth docling --quiet
)

set /p PY7="    [Web/API] flask, streamlit, dash, uvicorn, mcp? (Y/N): "
if /i "%PY7%"=="Y" (
    echo      Installing Web/API libraries...
    pip install flask streamlit dash uvicorn starlette mcp httpx requests --quiet
)

set /p PY8="    [GIS/Mapping] pyproj, shapely, folium? (Y/N): "
if /i "%PY8%"=="Y" (
    echo      Installing GIS/Mapping libraries...
    pip install pyproj shapely folium streamlit-folium geojson --quiet
)

set /p PY9="    [Jupyter] jupyter, jupyterlab, notebook? (Y/N): "
if /i "%PY9%"=="Y" (
    echo      Installing Jupyter libraries...
    pip install jupyter jupyterlab notebook ipykernel ipywidgets --quiet
)

set /p PY10="    [Utilities] pydantic, rich, Pillow, opencv, graphviz? (Y/N): "
if /i "%PY10%"=="Y" (
    echo      Installing Utility libraries...
    pip install pydantic rich click typer tqdm beautifulsoup4 lxml Pillow opencv-python graphviz tabulate python-dotenv PyYAML customtkinter pyinstaller pythonnet pywin32 --quiet
)

:: ============================================================
:: STEP 8: IDE Extensions
:: ============================================================
:EXTENSIONS
echo.
echo  [9/9] IDE Extensions (35 extensions)
echo.

:: Detect IDE CLI
set "IDE_CMD="
where antigravity-ide >nul 2>&1 && set "IDE_CMD=antigravity-ide"
if not defined IDE_CMD (
    if exist "%LOCALAPPDATA%\Programs\Antigravity IDE\bin\antigravity-ide.cmd" (
        set "IDE_CMD=%LOCALAPPDATA%\Programs\Antigravity IDE\bin\antigravity-ide.cmd"
    )
)
if not defined IDE_CMD (
    where code >nul 2>&1 && set "IDE_CMD=code"
)
if not defined IDE_CMD (
    where cursor >nul 2>&1 && set "IDE_CMD=cursor"
)

if not defined IDE_CMD (
    echo    WARNING: No IDE CLI found. Install extensions manually.
    echo    Extension list saved in: %INSTALL_DIR%extensions.txt
    goto :FINISH
)

echo    Using: !IDE_CMD!
echo.
echo    Categories:
echo      Python/Jupyter .... 9 extensions
echo      BIM/CAD ........... 4 extensions
echo      Database .......... 3 extensions
echo      Document Viewers .. 5 extensions
echo      AI Assistants ..... 3 extensions
echo      Dev Tools ......... 11 extensions
echo.

set /p EXT_CHOICE="    Install extensions? (A=all / S=select category / N=skip): "

if /i "%EXT_CHOICE%"=="N" goto :FINISH
if /i "%EXT_CHOICE%"=="S" goto :SELECT_EXT

:: Install all
echo.
echo    Installing all 35 extensions (this may take a few minutes)...
echo.
for /f "usebackq tokens=*" %%e in ("%INSTALL_DIR%extensions.txt") do (
    echo    Installing %%e...
    "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
)
echo.
echo    All extensions installed!
goto :FINISH

:SELECT_EXT
echo.

set /p CAT1="    [Python/Jupyter] ms-python, jupyter, pyrefly, debugpy? (Y/N): "
if /i "%CAT1%"=="Y" (
    for %%e in (ms-python.python ms-python.debugpy ms-python.vscode-python-envs ms-toolsai.jupyter ms-toolsai.jupyter-keymap ms-toolsai.jupyter-renderers ms-toolsai.vscode-jupyter-cell-tags ms-toolsai.vscode-jupyter-slideshow meta.pyrefly) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

set /p CAT2="    [BIM/CAD] IFC Viewer, CAD Viewer, DWG Viewer, PLY? (Y/N): "
if /i "%CAT2%"=="Y" (
    for %%e in (bharathikannann.vscode-ifc-viewer thingraph.cad-viewer thingraph.dwg-viewer kleinicke.ply-visualizer) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

set /p CAT3="    [Database] SQLite Viewer, Database Client? (Y/N): "
if /i "%CAT3%"=="Y" (
    for %%e in (qwtel.sqlite-viewer cweijan.vscode-database-client2 cweijan.dbclient-jdbc) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

set /p CAT4="    [Document Viewers] PDF, DOCX, PPTX, Office? (Y/N): "
if /i "%CAT4%"=="Y" (
    for %%e in (tomoki1207.pdf mathematic.vscode-pdf michaelsam94.docxviewerext mutyai.muty-pptviewer cweijan.vscode-office) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

set /p CAT5="    [AI Assistants] Claude Code, Qwen Code, Continue? (Y/N): "
if /i "%CAT5%"=="Y" (
    for %%e in (anthropic.claude-code qwenlm.qwen-code-vscode-ide-companion continue.continue) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

set /p CAT6="    [Dev Tools] Docker, Git, R, Ruby, Go, Clangd, Markdown? (Y/N): "
if /i "%CAT6%"=="Y" (
    for %%e in (ms-azuretools.vscode-docker ms-azuretools.vscode-containers github.vscode-pull-request-github golang.go llvm-vs-code-extensions.vscode-clangd davidanson.vscode-markdownlint reditorsupport.r reditorsupport.r-syntax oridwanbello.r-layout shopify.ruby-lsp googlecloudtools.datacloud) do (
        echo      Installing %%e...
        "!IDE_CMD!" --install-extension %%e --force >nul 2>&1
    )
)

:: ============================================================
:: FINISH
:: ============================================================
:FINISH
echo.
echo  ╔═══════════════════════════════════════════════════╗
echo  ║            Installation Complete!                 ║
echo  ╚═══════════════════════════════════════════════════╝
echo.
echo  Summary:
echo    Antigravity IDE .. OK
echo    Python ........... OK
echo    Ollama ........... OK
echo    MCP Server ....... OK (Smart Router v4.0)
echo    Skills ........... OK (3 skills)
echo    MCP Config ....... OK
echo    Python Libs ...... OK (10 categories)
echo    IDE Extensions ... OK (35 extensions)
echo.
echo  Models available:
ollama list 2>nul
echo.
echo  Next steps:
echo    1. Open/restart Antigravity IDE
echo    2. MCP Servers panel =^> ollama should be green with 5 tools
echo    3. Start chatting - Smart Router auto-selects models!
echo.

if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" >nul 2>&1

pause
