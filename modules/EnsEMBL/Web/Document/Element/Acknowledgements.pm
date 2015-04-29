=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Acknowledgements;

### Generates acknowledgements
### If you add ACKNOWLEDGEMENT entry to an ini file then you get
### a box with the ACKNOWLEDGEMENT text at the bottom of LH menu. It will link to /info/acknowledgement.html which 
### you will have to create
### If you add DB_BUILDER entry to an ini file then you get
### a box with the text DB built by XXX at the bottom of LH menu. It will link to the current species' homepage

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub content {
  my $self = shift;
  
  my $species_defs = $self->species_defs;
  my $species_path = $species_defs->species_path;
  my $ack_text     = $species_defs->ACKNOWLEDGEMENT;
  my $db_provider  = $species_defs->DB_BUILDER;
  my $content;
  
  if ($ack_text) {
    $content .= qq{
      <div>
        <ul>
          <li style="list-style:none"><a href="/info/acknowledgement.html">$ack_text</a></li>
        </ul>
      </div>
    };
  }

  if ($db_provider) {
    $content .= qq{
      <div>
        <ul>
          <li style="list-style:none"><a href="$species_path/Info/Index">DB built by $db_provider</a></li>
        </ul>
      </div>
    };
  }
  
  return $content;
}

1;
