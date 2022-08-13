@echo off

:: Enable delayed expansion to be able to use !ERRORLEVEL!
setlocal ENABLEDELAYEDEXPANSION

set num_args=0
for %%x in (%*) do Set /A num_args+=1

if "%num_args%" LSS "3" (
    echo At least three arguments are required
    goto help
)

if "%DILIGENT_BUILD_TYPE%" == "" (
    echo Required DILIGENT_BUILD_TYPE variable is not set
    goto help
)

if "%DILIGENT_BUILD_DIR%" == "" (
    echo Required DILIGENT_BUILD_DIR variable is not set
    goto help
)

if "%GOLDEN_IMAGE_WIDTH%" == "" (
    set GOLDEN_IMAGE_WIDTH=512
)
if "%GOLDEN_IMAGE_HEIGHT%" == "" (
    set GOLDEN_IMAGE_HEIGHT=512
)

:: ~ removes surrounding quotes
set golden_images_dir=%~1
shift

set golden_img_mode=%1
shift

set rest_args=
:loop1
    :: ~ removes surrounding quotes
    if "%~1"=="" goto end_loop1
    :: Do not remove quotes yet as this will ungroup arguments
    set rest_args=%rest_args% %1
    shift
    goto loop1
:end_loop1


echo Build type:  %DILIGENT_BUILD_TYPE%
echo Build dir:   %DILIGENT_BUILD_DIR%
echo Img mode:    %golden_img_mode%
echo Img dir:     %golden_images_dir%
echo Img size:    %GOLDEN_IMAGE_WIDTH% x %GOLDEN_IMAGE_HEIGHT%
echo App modes:   %rest_args%
echo.

cd ..

set Tutorials=Tutorial01_HelloTriangle^
              Tutorial02_Cube^
              Tutorial03_Texturing^
              Tutorial03_Texturing-C^
              Tutorial04_Instancing^
              Tutorial05_TextureArray^
              Tutorial06_Multithreading^
              Tutorial07_GeometryShader^
              Tutorial08_Tessellation^
              Tutorial09_Quads^
              Tutorial10_DataStreaming^
              Tutorial11_ResourceUpdates^
              Tutorial12_RenderTarget^
              Tutorial13_ShadowMap^
              Tutorial14_ComputeShader^
              Tutorial16_BindlessResources^
              Tutorial17_MSAA^
			  Tutorial18_Queries^
              Tutorial19_RenderPasses

set Samples=Atmosphere^
            GLTFViewer^
            NuklearDemo^
            Shadows

rem  ImguiDemo has fps counter in the UI, so we have to skip it

set ERROR=0
set APP_ID=1

for %%X in (%Tutorials%) do (
    call :gen_golden_img Tutorials %%X %rest_args% || set /a ERROR=!ERROR!+!APP_ID!
    set /a APP_ID=!APP_ID!*2
)

for %%X in (%Samples%) do (
   call :gen_golden_img Samples %%X %rest_args% || set /a ERROR=!ERROR!+!APP_ID!
   set /a APP_ID=!APP_ID!*2
)

cd Tests

EXIT /B %ERROR%



:gen_golden_img

    set app_folder=%1
    shift

    set app_name=%1
    shift

    rem  Who knows why, but without the echos below, the script fails on Appveyor.
    @echo Testing %app_folder%/%app_name%...
    @echo.

    set show_ui=1
    if "%app_folder%" == "Samples" (
        set show_ui=0
        if "%app_name%" == "ImguiDemo" set show_ui=1
    )
	if "%app_name%" == "Tutorial18_Queries" set show_ui=0
	
    set test_modes=
    :loop2
	    :: Do not remove quotes as this will ungroup arguments
        if "%~1"=="" goto end_loop2
        set test_modes=%test_modes% %1
        shift
        goto loop2
    :end_loop2

    cd "%app_folder%/%app_name%/assets"

    set golden_img_dir=%golden_images_dir%/%app_folder%/%app_name%
    if not exist "%golden_img_dir%" (
        md "%golden_img_dir%"
    )

    set EXIT_CODE=0
    for %%X in (%test_modes%) do (

        set app_path=%DILIGENT_BUILD_DIR%/DiligentSamples/%app_folder%/%app_name%
        if exist "!app_path!/%DILIGENT_BUILD_TYPE%" (
            set app_path=!app_path!/%DILIGENT_BUILD_TYPE%
        )
        set app_path=!app_path!/%app_name%.exe

        :: Get the backend name and extra arguments
        set extra_args=
        set mode_param=0
        for %%Y in (%%~X) do (
            if "%%Y" == "--mode" (
                set mode_param=1
            ) else (
                if "!mode_param!" == "1" (
                    set backend_name=%%Y
                    set mode_param=0
                ) else (
                    set extra_args=!extra_args! %%Y
                )
            )
        )
        set capture_name=%app_name%_gi_!backend_name!


        rem   !!!   ERRORLEVEL doesn't get updated inside control blocks like IF statements unless           !!!
        rem   !!!   !ERRORLEVEL! is used instead of %ERRORLEVEL% and delayed expansion is enabled as below:  !!!
        rem   !!!   setlocal ENABLEDELAYEDEXPANSION                                                          !!!
        rem   ~ removes quotes from %%~X
        !app_path! %%~X --width %GOLDEN_IMAGE_WIDTH% --height %GOLDEN_IMAGE_HEIGHT% --golden_image_mode %golden_img_mode% --capture_path %golden_img_dir% --capture_name !capture_name! --capture_format png --adapters_dialog 0 --show_ui %show_ui%

        if !ERRORLEVEL! NEQ 0 (
            if !ERRORLEVEL! GEQ 0 (
                echo Golden image validation FAILED for %app_name% [!backend_name!!extra_args!]: !ERRORLEVEL! inconsistent pixels found
                if "%golden_img_mode%" == "compare_update" echo Golden image updated
            ) else (
                if "%golden_img_mode%" == "compare" echo Golden image validation FAILED for %app_name% [!backend_name!!extra_args!]: unknown error
                if "%golden_img_mode%" == "capture" echo FAILED to generate golden image for %app_name% [!backend_name!!extra_args!]: unknown error
                if "%golden_img_mode%" == "compare_update" echo FAILED to validate or update golden image for %app_name% [!backend_name!!extra_args!]: unknown error
            )
            set EXIT_CODE=1
        ) else (
            if "%golden_img_mode%" == "compare" echo Golden image validation PASSED for %app_name% [!backend_name!!extra_args!]
            if "%golden_img_mode%" == "capture" echo Successfully generated golden image for %app_name% [!backend_name!!extra_args!]
            if "%golden_img_mode%" == "compare_update" echo Golden image validation PASSED for %app_name%. Image updated. [!backend_name!!extra_args!]
        )

		echo.
        echo.
    )

    cd ../../../

    EXIT /B %EXIT_CODE%



:help

    echo.
    echo === ProcessGoldenImages.bat ===
    echo.
    echo Required variables:
    echo.
    echo   DILIGENT_BUILD_TYPE - Build type (e.g. Debug, Release, etc.^)
    echo   DILIGENT_BUILD_DIR  - Path to the build directory
    echo.
    echo Optional variables:
    echo.
    echo   GOLDEN_IMAGE_WIDTH  - Golden image width (Default: 512^)
    echo   GOLDEN_IMAGE_HEIGHT - Golden image height (Default: 512^)
    echo.
    echo Command line format:
    echo.
    echo   ProcessGoldenImages.bat golden_images_dir golden_img_mode test_modes
    echo.
    echo     golden_images_dir - Path to the golden images directory
    echo     golden_img_mode   - golden image processing mode (capture, compare, or compare_update^)
    echo     test_modes        - list of test modes (e.g. "--mode d3d11" "--mode d3d11 --adapter sw" "--mode d3d12" "--mode gl" "--mode vk"^)
    echo. 
    echo Example:
    echo   set DILIGENT_BUILD_DIR=c:\git\DiligentEngine\build\Win64
    echo   set DILIGENT_BUILD_TYPE=Debug
    echo   ProcessGoldenImages.bat c:\git\DiligentTestData\GoldenImages compare "--mode d3d11" "--mode d3d12 --adapter sw"

    EXIT /B -1