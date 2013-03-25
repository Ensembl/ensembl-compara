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
