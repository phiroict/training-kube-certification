resource "aws_s3_bucket" "state-bucket" {
  bucket = "phiroict-state-bucket-training"
  tags = {
    Name = "phiroict-state-bucket-training"
    State = "Experimental"
    ExpiresAt = "20250101"
  }
}