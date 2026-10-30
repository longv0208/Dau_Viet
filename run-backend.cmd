@echo off
set "JAVA_HOME=E:\Java\jdk-21"
cd /d "E:\Telegram Desktop\Dau viet\Dau_Viet\dau-viet-backend"
call mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
