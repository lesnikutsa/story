import os
import io
import time
import configparser
from urllib.parse import quote, unquote
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer  # Используем ThreadingHTTPServer

# Чтение конфигурации
config = configparser.ConfigParser()
config.read('config.ini')

# Получение директории для шаринга из конфигурации
SHARE_DIR = config.get('settings', 'SHARE_DIR')

class CustomHTTPRequestHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        """Переопределяем метод для работы с SHARE_DIR в качестве корня"""
        # Убираем символы URL, возвращаем локальный путь
        path = unquote(path)
        # Безопасное приведение относительного пути
        path = os.path.normpath(path)
        # Полный путь к расшаренной директории
        full_path = os.path.join(SHARE_DIR, path.lstrip('/'))
        return full_path

    def list_directory(self, path):
        try:
            file_list = os.listdir(path)
        except OSError:
            self.send_error(404, "No permission to list directory")
            return None
        file_list.sort(key=lambda a: a.lower())
        r = []
        displaypath = os.path.basename(self.translate_path(path))
        
        # Создание заголовка страницы
        r.append('<!DOCTYPE html>')
        r.append(f'<html><title>Directory listing for {displaypath}</title>')
        r.append(f'<body><h2>Directory listing for {displaypath}</h2>')
        r.append('<hr><ul>')

        # Если не находимся в корне, добавляем ссылку для перехода на уровень вверх
        if self.path != '/':
            parent_dir = os.path.join(self.path, "..")
            r.append(f'<li><a href="{quote(parent_dir)}">../ </a></li>')

        # Список файлов и директорий с размером и временем для файлов
        for name in file_list:
            fullname = os.path.join(path, name)
            displayname = linkname = name
            if os.path.isdir(fullname):
                displayname = name + "/"
                linkname = name + "/"
                r.append(f'<li><a href="{quote(linkname)}">{displayname}</a> - Directory</li>')
            else:
                filesize = os.path.getsize(fullname)
                formatted_size = self.format_size(filesize)

                # Получение времени создания файла
                creation_time = os.path.getctime(fullname)
                formatted_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(creation_time))

                # Создание ссылки на файл с указанием размера и времени создания
                r.append(f'<li><a href="{quote(linkname)}">{displayname}</a> - {formatted_size} - Created on: {formatted_time}</li>')

        r.append('</ul><hr></body></html>')
        encoded = '\n'.join(r).encode('utf-8', 'surrogateescape')

        # Использование BytesIO для создания объекта, похожего на файл
        f = io.BytesIO(encoded)
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        return f  # Возврат объекта, похожего на файл

    # Вспомогательный метод для форматирования размера файла
    def format_size(self, size):
        """Конвертирует размер файла из байтов в более удобный формат (GB, MB, KB и т.д.)"""
        power = 1024
        n = 0
        units = ['bytes', 'KB', 'MB', 'GB', 'TB']
        while size >= power and n < len(units) - 1:
            size /= power
            n += 1
        return f'{size:.2f} {units[n]}'

if __name__ == '__main__':
    PORT = 8000
    server_address = ("", PORT)

    # Используем ThreadingHTTPServer вместо HTTPServer
    httpd = ThreadingHTTPServer(server_address, CustomHTTPRequestHandler)
    
    print(f"Serving on port {PORT}, sharing directory: {SHARE_DIR}")
    httpd.serve_forever()
