#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import json
import time
import logging
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import subprocess

class APKDownloadHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.apk_dir = '/var/www/apk-downloads'
        super().__init__(*args, directory=self.apk_dir, **kwargs)
    
    def log_message(self, format, *args):
        """自定义日志格式"""
        logging.info(f"{self.address_string()} - {format%args}")
    
    def do_GET(self):
        """处理GET请求"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/':
            self.send_index_page()
        elif parsed_path.path == '/api/status':
            self.send_status_api()
        elif parsed_path.path == '/api/list':
            self.send_apk_list_api()
        elif parsed_path.path.endswith('.apk'):
            super().do_GET()
        else:
            self.send_error(404, "File not found")
    
    def send_index_page(self):
        """发送主页"""
        try:
            apk_files = self.get_apk_files()
            
            html_content = self.generate_html_page(apk_files)
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(html_content.encode('utf-8'))
            
        except Exception as e:
            logging.error(f"Error generating index page: {e}")
            self.send_error(500, "Internal Server Error")
    
    def send_status_api(self):
        """发送状态API"""
        try:
            status_info = {
                'status': 'running',
                'timestamp': datetime.now().isoformat(),
                'server_ip': '45.130.146.21',
                'server_port': 8080,
                'apk_count': len(self.get_apk_files())
            }
            
            self.send_json_response(status_info)
            
        except Exception as e:
            logging.error(f"Error in status API: {e}")
            self.send_error(500, "Internal Server Error")
    
    def send_apk_list_api(self):
        """发送APK列表API"""
        try:
            apk_files = self.get_apk_files()
            self.send_json_response(apk_files)
            
        except Exception as e:
            logging.error(f"Error in APK list API: {e}")
            self.send_error(500, "Internal Server Error")
    
    def send_json_response(self, data):
        """发送JSON响应"""
        json_data = json.dumps(data, indent=2, ensure_ascii=False)
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json; charset=utf-8')
        self.end_headers()
        self.wfile.write(json_data.encode('utf-8'))
    
    def get_apk_files(self):
        """获取APK文件列表"""
        apk_files = []
        
        try:
            if os.path.exists(self.apk_dir):
                for filename in os.listdir(self.apk_dir):
                    if filename.endswith('.apk'):
                        filepath = os.path.join(self.apk_dir, filename)
                        stat = os.stat(filepath)
                        
                        apk_files.append({
                            'name': filename,
                            'size': stat.st_size,
                            'modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                            'download_url': f"/{filename}",
                            'size_mb': round(stat.st_size / (1024 * 1024), 2)
                        })
                
                # 按修改时间排序（最新的在前）
                apk_files.sort(key=lambda x: x['modified'], reverse=True)
        
        except Exception as e:
            logging.error(f"Error getting APK files: {e}")
        
        return apk_files
    
    def generate_html_page(self, apk_files):
        """生成HTML页面"""
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>APK下载中心</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }}
        .header h1 {{
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }}
        .header p {{
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.1em;
        }}
        .content {{
            padding: 30px;
        }}
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .stat-card {{
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }}
        .stat-number {{
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }}
        .stat-label {{
            color: #666;
            margin-top: 5px;
        }}
        .apk-list {{
            margin-top: 30px;
        }}
        .apk-item {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px;
            margin-bottom: 10px;
            background: #f8f9fa;
            border-radius: 8px;
            transition: all 0.3s ease;
        }}
        .apk-item:hover {{
            background: #e9ecef;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }}
        .apk-info {{
            flex: 1;
        }}
        .apk-name {{
            font-weight: bold;
            color: #333;
            font-size: 1.1em;
        }}
        .apk-details {{
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }}
        .download-btn {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 10px 20px;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s ease;
        }}
        .download-btn:hover {{
            opacity: 0.9;
            transform: scale(1.05);
        }}
        .empty-state {{
            text-align: center;
            padding: 60px 20px;
            color: #666;
        }}
        .empty-state-icon {{
            font-size: 4em;
            margin-bottom: 20px;
        }}
        .footer {{
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #e9ecef;
        }}
        .api-info {{
            background: #e3f2fd;
            border: 1px solid #2196f3;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
        }}
        .api-info h3 {{
            margin-top: 0;
            color: #1976d2;
        }}
        .api-endpoint {{
            font-family: 'Courier New', monospace;
            background: #f5f5f5;
            padding: 5px 8px;
            border-radius: 3px;
            margin: 5px 0;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📱 APK下载中心</h1>
            <p>自动监控GitHub仓库，提供最新APK文件下载</p>
        </div>
        
        <div class="content">
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number">{len(apk_files)}</div>
                    <div class="stat-label">可用APK文件</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">45.130.146.21:8080</div>
                    <div class="stat-label">服务器地址</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">{current_time}</div>
                    <div class="stat-label">当前时间</div>
                </div>
            </div>
            
            <div class="api-info">
                <h3>🔧 API接口</h3>
                <p><strong>状态查询:</strong> <span class="api-endpoint">GET /api/status</span></p>
                <p><strong>APK列表:</strong> <span class="api-endpoint">GET /api/list</span></p>
            </div>
            
            <div class="apk-list">
                <h2>📦 可下载的APK文件</h2>
"""

        if apk_files:
            for apk in apk_files:
                html += f"""
                <div class="apk-item">
                    <div class="apk-info">
                        <div class="apk-name">{apk['name']}</div>
                        <div class="apk-details">
                            大小: {apk['size_mb']} MB | 
                            更新时间: {apk['modified'][:19].replace('T', ' ')}
                        </div>
                    </div>
                    <a href="{apk['download_url']}" class="download-btn">下载</a>
                </div>
"""
        else:
            html += """
                <div class="empty-state">
                    <div class="empty-state-icon">📭</div>
                    <h3>暂无APK文件</h3>
                    <p>系统正在监控GitHub仓库，有新版本时会自动下载</p>
                </div>
"""

        html += f"""
            </div>
        </div>
        
        <div class="footer">
            <p>🤖 自动下载服务运行中 | 每10分钟检查一次更新</p>
            <p>源仓库: <a href="https://github.com/z0brk/netamade-releases" target="_blank">z0brk/netamade-releases</a></p>
        </div>
    </div>
</body>
</html>
"""
        
        return html

def setup_logging():
    """设置日志"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('/var/log/apk-server.log'),
            logging.StreamHandler(sys.stdout)
        ]
    )

def main():
    """主函数"""
    # 设置日志
    setup_logging()
    
    # 确保APK目录存在
    apk_dir = '/var/www/apk-downloads'
    os.makedirs(apk_dir, exist_ok=True)
    
    # 服务器配置
    server_address = ('0.0.0.0', 8080)
    httpd = HTTPServer(server_address, APKDownloadHandler)
    
    logging.info(f"APK下载服务器启动")
    logging.info(f"服务地址: http://45.130.146.21:8080")
    logging.info(f"APK目录: {apk_dir}")
    logging.info("按 Ctrl+C 停止服务器")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logging.info("正在停止服务器...")
        httpd.server_close()
        logging.info("服务器已停止")

if __name__ == '__main__':
    main()