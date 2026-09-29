package com.wms.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "wms.security")
public class SecurityProperties {
    private String issuer = "http://localhost:8081";
    private long accessTokenMinutes = 15;
    private long refreshTokenDays = 7;
    private String keyDirectory = "./data/auth-keys";

    public String getIssuer() { return issuer; }
    public void setIssuer(String issuer) { this.issuer = issuer; }
    public long getAccessTokenMinutes() { return accessTokenMinutes; }
    public void setAccessTokenMinutes(long accessTokenMinutes) { this.accessTokenMinutes = accessTokenMinutes; }
    public long getRefreshTokenDays() { return refreshTokenDays; }
    public void setRefreshTokenDays(long refreshTokenDays) { this.refreshTokenDays = refreshTokenDays; }
    public String getKeyDirectory() { return keyDirectory; }
    public void setKeyDirectory(String keyDirectory) { this.keyDirectory = keyDirectory; }
}
