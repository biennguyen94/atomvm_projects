# Build image with Dockerfile
```
docker build --network host -t bien_atomvm.test .
```

# Delpoy container with image
```
docker run --name bien_atomvm --net host -it bien_atomvm.test
```

# Access to container 
```
docker start bien_atomvm
docker exec -it bien_atomvm bash
```