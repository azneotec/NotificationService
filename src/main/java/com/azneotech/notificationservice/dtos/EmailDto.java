package com.azneotech.notificationservice.dtos;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class EmailDto {
    private String to;
    private String from;
    private String subject;
    private String body;
}
