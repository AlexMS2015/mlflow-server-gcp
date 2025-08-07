FROM python:3.12-slim

# 1

WORKDIR /

COPY requirements.txt server.sh .

RUN pip install --upgrade pip && pip install -r requirements.txt

EXPOSE 8080

RUN chmod +x server.sh

ENTRYPOINT [ "./server.sh" ]