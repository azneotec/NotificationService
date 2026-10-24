package com.azneotech.notificationservice.clients;

import com.azneotech.notificationservice.utils.EmailUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.kafka.annotation.KafkaListener;

import javax.mail.Session;
import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mockStatic;

class KafkaConsumerEmailClientTest {

    private final KafkaConsumerEmailClient client = new KafkaConsumerEmailClient(new ObjectMapper(), "app-password");

    @Test
    void sendsTheSubjectAndBodyCarriedByTheMessage() {
        String message = """
                {"to":"alice@example.com","from":"azneotech@gmail.com",
                 "subject":"Reset your password","body":"Use this link: http://localhost:3000/reset-password?token=abc"}
                """;

        try (MockedStatic<EmailUtil> emailUtil = mockStatic(EmailUtil.class)) {
            client.sendEmail(message);

            emailUtil.verify(() -> EmailUtil.sendEmail(
                    any(Session.class),
                    eq("alice@example.com"),
                    eq("Reset your password"),
                    eq("Use this link: http://localhost:3000/reset-password?token=abc")));
        }
    }

    @Test
    void listensToTheSignupPasswordResetAndOrderNotificationTopics() throws NoSuchMethodException {
        Method listener = KafkaConsumerEmailClient.class.getMethod("sendEmail", String.class);

        assertThat(listener.getAnnotation(KafkaListener.class).topics())
                .containsExactlyInAnyOrder("signup", "password-reset", "order-notification");
    }

    @Test
    void rejectsAMalformedMessage() {
        assertThatThrownBy(() -> client.sendEmail("not json")).isInstanceOf(RuntimeException.class);
    }
}
