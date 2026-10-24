package com.azneotech.notificationservice.clients;

import com.azneotech.notificationservice.dtos.EmailDto;
import com.azneotech.notificationservice.utils.EmailUtil;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import javax.mail.Authenticator;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import java.util.Properties;

/**
 * Sends the email described by each message on the {@code signup} (welcome), {@code password-reset} and
 * {@code order-notification} (order confirmation and delivery updates) topics. The producer (UserAuthService
 * or OrderManagementService) decides the recipient, subject and body; this class only delivers it.
 */
@Component
public class KafkaConsumerEmailClient {

    private final ObjectMapper objectMapper;
    private final String mailPassword;

    public KafkaConsumerEmailClient(
            ObjectMapper objectMapper,
            @Value("${notification.mail.password}") String mailPassword
    ) {
        this.objectMapper = objectMapper;
        this.mailPassword = mailPassword;
    }

    @KafkaListener(topics = {"signup", "password-reset", "order-notification"}, groupId = "emailService")
    public void sendEmail(String message) {
        try {
            EmailDto emailDto = objectMapper.readValue(message, EmailDto.class);

            Properties props = new Properties();
            props.put("mail.smtp.host", "smtp.gmail.com"); //SMTP Host
            props.put("mail.smtp.port", "587"); //TLS Port
            props.put("mail.smtp.auth", "true"); //enable authentication
            props.put("mail.smtp.starttls.enable", "true"); //enable STARTTLS

            //create Authenticator object to pass in Session.getInstance argument
            Authenticator auth = new Authenticator() {
                //override the getPasswordAuthentication method
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(emailDto.getFrom(), mailPassword);
                }
            };
            Session session = Session.getInstance(props, auth);

            EmailUtil.sendEmail(session, emailDto.getTo(), emailDto.getSubject(), emailDto.getBody());

        } catch (JsonProcessingException e) {
            throw new RuntimeException(e.getMessage());
        }
    }

}
