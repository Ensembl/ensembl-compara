=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::Help;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object);

sub caption       { return 'Help';  }
sub short_caption { return 'Help';  }

sub movie_problems {
  return [
    {'value' => 'no_load',   'caption' => 'Movie did not appear'           },
    {'value' => 'playback',  'caption' => 'Playback was jerky'             },
    {'value' => 'no_sound',  'caption' => 'No sound'                       },
    {'value' => 'bad_sound', 'caption' => 'Poor quality sound'             },
    {'value' => 'other',     'caption' => 'Other (please describe below)'  },
  ];
}

1;
