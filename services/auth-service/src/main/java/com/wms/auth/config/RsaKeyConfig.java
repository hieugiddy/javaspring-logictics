package com.wms.auth.config;

import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtValidators;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.UUID;

@Configuration
@EnableConfigurationProperties(SecurityProperties.class)
public class RsaKeyConfig {

    @Bean
    KeyPair keyPair(SecurityProperties properties) {
        try {
            Path dir = Path.of(properties.getKeyDirectory());
            Path privateFile = dir.resolve("private.pem");
            Path publicFile = dir.resolve("public.pem");
            if (Files.exists(privateFile) && Files.exists(publicFile)) {
                return new KeyPair(readPublic(publicFile), readPrivate(privateFile));
            }
            Files.createDirectories(dir);
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            KeyPair pair = generator.generateKeyPair();
            Files.writeString(privateFile, toPem("PRIVATE KEY", pair.getPrivate().getEncoded()));
            Files.writeString(publicFile, toPem("PUBLIC KEY", pair.getPublic().getEncoded()));
            return pair;
        } catch (Exception e) {
            throw new IllegalStateException("Unable to load or create RSA signing keys", e);
        }
    }

    @Bean
    RSAKey rsaJwk(KeyPair keyPair) {
        return new RSAKey.Builder((RSAPublicKey) keyPair.getPublic())
                .privateKey((RSAPrivateKey) keyPair.getPrivate())
                .keyID(UUID.randomUUID().toString())
                .build();
    }

    @Bean
    JWKSet jwkSet(RSAKey rsaKey) {
        return new JWKSet(rsaKey);
    }

    @Bean
    JwtEncoder jwtEncoder(JWKSet jwkSet) {
        JWKSource<SecurityContext> source = new ImmutableJWKSet<>(jwkSet);
        return NimbusJwtEncoder.withJwkSource(source).build();
    }

    @Bean
    JwtDecoder jwtDecoder(KeyPair keyPair, SecurityProperties properties) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withPublicKey((RSAPublicKey) keyPair.getPublic()).build();
        OAuth2TokenValidator<Jwt> issuer = JwtValidators.createDefaultWithIssuer(properties.getIssuer());
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(issuer));
        return decoder;
    }

    private static RSAPublicKey readPublic(Path path) throws Exception {
        byte[] bytes = decodePem(Files.readString(path), "PUBLIC KEY");
        return (RSAPublicKey) KeyFactory.getInstance("RSA").generatePublic(new X509EncodedKeySpec(bytes));
    }

    private static RSAPrivateKey readPrivate(Path path) throws Exception {
        byte[] bytes = decodePem(Files.readString(path), "PRIVATE KEY");
        return (RSAPrivateKey) KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(bytes));
    }

    private static byte[] decodePem(String pem, String type) {
        String normalized = pem
                .replace("-----BEGIN " + type + "-----", "")
                .replace("-----END " + type + "-----", "")
                .replaceAll("\\s", "");
        return Base64.getDecoder().decode(normalized);
    }

    private static String toPem(String type, byte[] bytes) {
        String encoded = Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(bytes);
        return "-----BEGIN " + type + "-----\n" + encoded + "\n-----END " + type + "-----\n";
    }
}
