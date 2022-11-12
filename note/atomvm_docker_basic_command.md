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

# Push image to container
```
docker tag bien_atomvm.test biennguyen94/atomvm:v1
docker push biennguyen94/atomvm:v1
```