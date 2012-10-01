# $Id$

package EnsEMBL::Web::Component::Variation;

use strict;

use base qw(EnsEMBL::Web::Component);

sub trim_large_allele_string {
  my $self        = shift;
  my $allele      = shift;
  my $cell_prefix = shift;
  my $length      = shift;
  
  $length ||= 50;
  return $self->trim_large_string($allele,$cell_prefix,sub {
    # how to trim an allele string...
    my $trimmed = 0;
    my @out = map {
      if(length $_ > $length) {
        $trimmed = 1;
        $_ = substr($_,0,$length)."...";
      }
      $_;
    } (split m!/!,$_[0]);
    $out[-1] .= "..." unless $trimmed;
    return join("/",@out);
  });
}

1;

