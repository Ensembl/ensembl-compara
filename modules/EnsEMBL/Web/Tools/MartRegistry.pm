=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
