# Java Logistics — Môi trường, Build và CI/CD

Tài liệu này gộp hướng dẫn cài môi trường, Gradle/WAR/Tomcat, Docker, Jenkins, các cổng kiểm soát triển khai và danh mục tệp liên quan.

> **Trạng thái scaffold:** workspace hiện có thư mục service dạng khung nhưng chưa có Gradle Wrapper, `build.gradle` cho service, mã ứng dụng hoặc script hỗ trợ. Các lệnh dưới đây mô tả quy trình mục tiêu; cần tạo các thành phần đó trước khi chạy.

## 1. Kiến trúc build và triển khai

```text
Git push
  -> Jenkins checkout mã nguồn
  -> Gradle compile/test/integration test
  -> bootWar
  -> lưu WAR theo phiên bản
  -> deploy lên Tomcat DEV
  -> health check + API smoke test
  -> phê duyệt
  -> promote lên staging/production
```

Mỗi service được đóng gói thành WAR và chạy trên Tomcat ngoài tương thích. PostgreSQL là nguồn dữ liệu chuẩn; Redis dùng làm cache/điều phối; RabbitMQ vận chuyển sự kiện bất đồng bộ.

## 2. Bộ công cụ

| Công cụ | Phiên bản nền | Mục đích |
|---|---|---|
| JDK | 17 | Biên dịch và chạy Spring Boot 3 |
| Gradle | Gradle Wrapper | Build và test nhất quán |
| Spring Boot | 3.x, cần chốt phiên bản tương thích | Web/API và runtime |
| PostgreSQL | Theo phiên bản dự án | Lưu dữ liệu của service |
| Redis | Theo phiên bản dự án | Cache, giới hạn tốc độ, một số khóa |
| RabbitMQ | Theo phiên bản dự án | Gửi/nhận sự kiện nghiệp vụ |
| Tomcat | 10.1 tương thích Servlet stack đã chọn | Chạy WAR bên ngoài |
| Docker | Docker Desktop/Engine + Compose | Chạy phụ thuộc và container cục bộ |
| Jenkins | LTS | Điều phối CI/CD |
| IDE/công cụ API | IntelliJ, Postman/trình duyệt | Phát triển và kiểm tra API |

Commit `gradlew`, `gradlew.bat` và `gradle/wrapper/` để máy phát triển và CI dùng cùng phiên bản; không phụ thuộc Gradle cài toàn cục.

## 3. Cài môi trường cục bộ

1. Cài JDK 17; kiểm tra `java -version` và `javac -version`.
2. Mở thư mục Gradle có `settings.gradle`/`build.gradle` trong IntelliJ.
3. Kiểm tra Wrapper bằng `./gradlew --version` (Windows dùng `./gradlew.bat --version`).
4. Khởi động hạ tầng cục bộ:

```bash
docker compose -f infrastructure/docker-compose.yml up -d postgres redis rabbitmq
docker compose -f infrastructure/docker-compose.yml ps
```

5. Chỉ dùng thông tin mẫu bên dưới cho môi trường local; môi trường khác phải lấy bí mật từ kho quản lý secret.

| Thành phần | Host | Port | Giá trị mẫu local |
|---|---|---:|---|
| PostgreSQL | `localhost` | 5432 | database/user/password `warehouse` |
| Redis | `localhost` | 6379 | Không mật khẩu nếu Compose local chưa cấu hình |
| RabbitMQ AMQP | `localhost` | 5672 | Theo thông tin đăng nhập trong Compose |
| RabbitMQ UI | `localhost` | 15672 | Theo thông tin đăng nhập trong Compose |
| API Gateway | `localhost` | 8080 | Điểm vào API |
| User/Product/Inventory/Order/Shipping/Notification | `localhost` | 8081-8086 | Mỗi service một port/container |
| Tomcat | `localhost` | 8080 mặc định | Điều chỉnh theo cấu hình nếu chạy nhiều instance |

Không commit mật khẩu, khóa ký JWT, SSH key hoặc URL production chứa thông tin đăng nhập. Ví dụ cấu hình nằm trong `docs/templates/application-security.yml` và `docs/templates/build.gradle.example`.

### Lệnh trên Windows

```powershell
java -version
$env:JAVA_HOME="C:\Program Files\Java\jdk-17"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
.\gradlew.bat --version
.\gradlew.bat clean test bootWar
```

Linux/macOS:

```bash
java -version
./gradlew --version
./gradlew clean test bootWar
```

## 4. Danh sách service và port

| Service | Trách nhiệm | Port |
|---|---|---:|
| API Gateway | Định tuyến và ranh giới xác thực | 8080 |
| User Service | Người dùng, vai trò, đăng nhập, refresh-token, phát JWT | 8081 |
| Product Service | Danh mục sản phẩm và category | 8082 |
| Inventory Service | Kho, zone, tồn kho và lịch sử tồn | 8083 |
| Order Service | Đơn nhập/xuất và trạng thái đơn | 8084 |
| Shipping Service | Shipment và trạng thái tracking | 8085 |
| Notification Service | API notification và RabbitMQ consumer | 8086 |

Khi phát triển, nên chạy mỗi service trên một Tomcat instance/container. Nếu nhiều WAR dùng chung Tomcat thì chúng dùng chung HTTP port và phân biệt bằng context path; cần ghi rõ ánh xạ đó.

## 5. Gradle WAR và Tomcat ngoài

Luồng artifact mục tiêu:

```text
Mã Java -> Gradle Wrapper -> bootWar -> service.war -> Tomcat ngoài -> HTTP API
```

### Yêu cầu Gradle

- Áp dụng plugin `java`, `war`, Spring Boot và dependency-management.
- Dùng Java toolchain 17.
- Đánh dấu Tomcat ngoài là `providedRuntime`.
- Cấu hình `tasks.named('test') { useJUnitPlatform() }`.
- Chốt các phiên bản Spring Boot, MyBatis và springdoc tương thích.

Các dependency tiêu biểu:

```groovy
implementation 'org.springframework.boot:spring-boot-starter-web'
implementation 'org.springframework.boot:spring-boot-starter-validation'
implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
implementation 'org.mybatis.spring.boot:mybatis-spring-boot-starter:<PINNED_VERSION>'
implementation 'org.springframework.boot:spring-boot-starter-security'
implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'
implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:<PINNED_VERSION>'
runtimeOnly 'org.postgresql:postgresql'
providedRuntime 'org.springframework.boot:spring-boot-starter-tomcat'
```

Lớp khởi động ứng dụng kế thừa `SpringBootServletInitializer` và override `configure(SpringApplicationBuilder)` để đăng ký Spring Boot application. Artifact đầu ra: `build/libs/<service>.war`.

```bash
./gradlew clean test bootWar
```

Windows:

```powershell
.\gradlew.bat clean test bootWar
```

Chép WAR vào `<TOMCAT_HOME>/webapps/`. Tomcat suy ra context path từ tên WAR nếu chưa cấu hình riêng. Kiểm tra `/actuator/health`, sau đó kiểm tra API và Swagger theo context path cuối cùng.

### Kiểm tra Swagger/OpenAPI

Đường dẫn chuẩn, có thể kèm context path:

```text
/swagger-ui.html
/v3/api-docs
/v3/api-docs.yaml
```

Mỗi API mới cần mô tả DTO request/response, validation, quyền, success/error response và Bearer security trong OpenAPI. Không dùng JPA Entity làm hợp đồng API.

## 6. Docker

Docker đóng gói WAR cùng runtime Tomcat ngoài. Pin phiên bản image cụ thể, không dùng tag trôi nổi.

```dockerfile
FROM gradle:<PINNED_VERSION>-jdk17 AS build
WORKDIR /app
COPY . .
RUN ./gradlew clean test bootWar --no-daemon

FROM tomcat:10.1-jdk17
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /app/build/libs/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
```

Compose local cung cấp PostgreSQL, Redis và RabbitMQ. Truyền thông tin DB, khóa JWT và broker qua environment/secret; không đóng gói chúng vào image. Cung cấp `/actuator/health` để health check và kiểm tra sau deploy.

## 7. Jenkins CI/CD

### Các stage

```text
Checkout -> Gradle validation -> Unit test -> Integration test
         -> Static analysis -> bootWar -> Archive WAR
         -> Deploy DEV -> Health check -> Smoke test
         -> Approval -> Staging/Production
```

Lệnh build:

```bash
./gradlew clean test --no-daemon
./gradlew bootWar --no-daemon
```

Pipeline phải fail và dừng promote nếu compile, unit/integration test, đóng gói, health check hoặc smoke test lỗi. Jenkins agent Linux dùng `sh`; agent Windows dùng `bat` và `gradlew.bat`.

### Jenkinsfile mẫu

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Test') {
            steps { sh './gradlew clean test --no-daemon' }
        }
        stage('Package WAR') {
            steps { sh './gradlew bootWar --no-daemon' }
        }
        stage('Archive WAR') {
            steps {
                archiveArtifacts artifacts: '**/build/libs/*.war', fingerprint: true
            }
        }
        stage('Deploy DEV') {
            steps { echo 'Tải WAR có phiên bản lên Tomcat DEV' }
        }
        stage('Smoke Test') {
            steps { sh 'curl -f http://dev.example.com/actuator/health' }
        }
    }
    post {
        always {
            junit allowEmptyResults: true,
                  testResults: '**/build/test-results/test/*.xml'
        }
    }
}
```

Thay bước deploy DEV mẫu bằng cơ chế SCP/SSH hoặc Tomcat Manager đã chọn. Lưu Git, registry, SSH, DB, JWT và RabbitMQ credentials trong Jenkins Credentials/kho secret, không lưu trong Git.

### Nhánh, phiên bản và rollback

```text
feature/* -> develop -> staging -> main/production
```

Gắn artifact bằng Git commit SHA bất biến hoặc release version. Lưu WAR hiện tại và WAR trước đó. Nếu health/smoke test fail: dừng promote, khôi phục WAR trước, restart/redeploy rồi chạy lại health và smoke test. Promote cùng một artifact giữa các môi trường, không build lại binary khác nhau.

## 8. Lộ trình triển khai 30 ngày

| Ngày | Kết quả cần đạt |
|---|---|
| 1 | JDK/IDE/Gradle, WAR đầu tiên, Tomcat, Swagger |
| 2-4 | Spring DI/layer, REST, DTO validation, error contract |
| 5-9 | PostgreSQL/schema/index, JPA/Hibernate, MyBatis search/performance |
| 10-13 | User Service, hash mật khẩu, JWT, refresh rotation, RBAC |
| 14-15 | Transaction, locking, order/inventory state change |
| 16-17 | Redis cache-aside, TTL, invalidation, rate-limit concept |
| 18-20 | RabbitMQ event, retry/DLQ/idempotency, notification consumer |
| 21 | Gateway và ranh giới sở hữu service |
| 22-25 | JUnit, Mockito, API/security/messaging integration test |
| 26 | Rà soát SQL/query/connection pool |
| 27 | Docker image WAR/Tomcat và runtime local |
| 28-29 | Jenkins CI/CD, deploy, health/smoke, rollback |
| 30 | Demo end-to-end và rà Definition of Done |

Nhịp học mỗi ngày: chỉ học phần phục vụ deliverable trong ngày, triển khai, test/debug, ghi chú và commit. Tiêu chí nghiệp vụ chi tiết nằm trong `README_SCREEN_SPEC.md`.

## 9. Danh mục file CI/CD

| Đường dẫn | Trách nhiệm |
|---|---|
| `infrastructure/docker-compose.yml` | PostgreSQL, Redis, RabbitMQ local |
| `infrastructure/jenkins/Jenkinsfile` | Điểm vào Jenkins pipeline |
| `docs/templates/build.gradle.example` | Mẫu Gradle WAR và dependency |
| `docs/templates/application-security.yml` | Ví dụ context path, JWT, Swagger, health |
| `gradlew`, `gradlew.bat`, `gradle/wrapper/` | Gradle Wrapper đã pin phiên bản |
| `README_SCREEN_SPEC.md` | Hợp đồng nghiệp vụ, API, dữ liệu và tiêu chí nghiệm thu |

Thư mục `scripts/` hiện chỉ là chỗ dành cho setup local, migration, health/smoke test, build image và deploy helper trong tương lai; chưa có các script đó.
