# imagem base 
FROM python:3.9-slim

# diretório 
WORKDIR /app

# dependências 
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# copiar o resto
COPY . .

# porta 80 
EXPOSE 80
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
