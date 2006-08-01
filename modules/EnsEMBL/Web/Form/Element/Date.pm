package EnsEMBL::Web::Form::Element::Date;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub render {
  my $self = shift;
  $html = "<html>";
  for $month (0..11) {
  
  }
  return format_date($self, time);
}

sub format_date {
  my ($self, $time) = @_;
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
  return sprintf("%s %s", $self->month($mon), $self->year($year));
}


sub year {
  my ($self, $year_count) = @_;
  return $year_count + 1900;
}


sub month {
  my ($self, $month_count) = @_;
  my $month = "";
  $month = "January" if $month_count == 0;
  $month = "February" if $month_count == 1;
  $month = "March" if $month_count == 2;
  $month = "April" if $month_count == 3;
  $month = "May" if $month_count == 4;
  $month = "June" if $month_count == 5;
  $month = "July" if $month_count == 6;
  $month = "August" if $month_count == 7;
  $month = "September" if $month_count == 8;
  $month = "October" if $month_count == 9;
  $month = "November" if $month_count == 10;
  $month = "December" if $month_count == 11;
  return $month;
}

1;
