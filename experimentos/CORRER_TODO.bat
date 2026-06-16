@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  Experimentos NSGA-II (modo COMPLETO) - tarda ~2-3 horas.
echo  Resultados en la subcarpeta resultados\ (CSVs incrementales).
echo  Para cortar antes: cierra esta ventana (lo avanzado queda guardado).
echo ============================================================
wsl bash ./CORRER_TODO_HEUR.sh completo
echo.
echo  LISTO. Revisa la carpeta resultados\
pause
