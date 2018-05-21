variable region {
  default = "ap-southeast-2"
}

variable thing {
  description = "AWS Thing name."
  default     = "kodi"
}

variable host {
  description = "Kodi host address."
  default     = "osmc.local"
}

variable user {
  description = "Kodi user."
  default     = "osmc"
}

variable password {
  description = "Kodi host password."
}

variable root_cert_file_url {
  description = "Root Certificate File URL."
  default     = "https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem"
}

variable lambda_artifact {
  description = "The path to the lambda zip artifact."
  default     = "lambda.zip"
}