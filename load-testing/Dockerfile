FROM locustio/locust:2.24.0

WORKDIR /mnt/locust
COPY locustfile.py .

EXPOSE 8089

ENTRYPOINT ["locust"]
CMD ["-f", "/mnt/locust/locustfile.py"]
