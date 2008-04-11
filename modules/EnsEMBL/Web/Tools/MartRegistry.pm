package EnsEMBL::Web::Tools::MartRegistry;

use strict;

sub create {
  ### Creates mart registry (XML)
  ### Returns: registry content (string)
  my( $databases, $marts ) = @_;
  my $reg = '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MartRegistry>
<MartRegistry>';

  foreach my $mart ( sort keys %$marts ) {
    my( $default, $visible, @name ) = @{$marts->{$mart}};
    if( $databases->{$mart} ) {
      my $T = $databases->{$mart};
      $reg .= sprintf( '
<MartDBLocation
   databaseType = "%s"
       database = "%s"
           name = "%s"
         schema = "%s"
           host = "%s"
           port = "%s"
           user = "%s"
       password = "%s"
    displayName = "%s"
        visible = "%s"
        default = "%s"
       martUser = ""
includeDatasets = ""
   includeMarts = ""
/>',
        $T->{DRIVER}, $T->{NAME},   $mart,  $T->{NAME}, $T->{HOST}, $T->{PORT},
        $T->{USER},   $T->{PASS},   "@name", $visible?1:'', $default?1:''
      );
    }
  }
  $reg .= "\n</MartRegistry>\n";
#  warn $reg;
  return $reg;
}

1;
