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

package EnsEMBL::Web::Document::HTML::MirrorsPage;

use strict;
use warnings;

use Exporter qw(import);

use EnsEMBL::Web::SpeciesDefs;

our @EXPORT = qw(mirrors_list);

sub mirrors_list {
  return [
    'UK'      => {'name'  => 'UK (Sanger Institute)',
                  'url'   => '//www.ensembl.org',
                  'blurb' => 'Main site, best for Europe, Africa and Middle East',
                  'flag'  => 'flag_uk.png',
                  },
    'USWEST'  => {'name'  => 'US West (Amazon AWS)',
                  'url'   => '//uswest.ensembl.org',
                  'blurb' => 'Cloud-based mirror on West Coast of US',
                  'flag'  => 'flag_usa.png',
                  },
    'USEAST'  => {'name'  => 'US East (Amazon AWS)',
                  'url'   => '//useast.ensembl.org',
                  'blurb' => 'Cloud-based mirror on East Coast of US',
                  'flag'  => 'flag_usa.png',
                  },
    'ASIA'    => {'name'  => 'Asia (Amazon AWS)',
                  'url'   => '//asia.ensembl.org',
                  'blurb' => 'Cloud-based mirror in Singapore',
                  'flag'  => 'flag_sg.png',
                  },
  ];
}

sub render {
  my $mirrors = mirrors_list;
  my $html    = [];
  my $sd      = EnsEMBL::Web::SpeciesDefs->new;

  while (my ($key, $mirror) = splice @$mirrors, 0, 2) {
    my $flag = sprintf '<img src="%s%s" alt="flag" style="width:40px;height:24px;vertical-align:middle;border:1px solid #ccc;" />', $sd->img_url, $mirror->{'flag'} || 'blank.gif';
    my $site = '<strong>'.$mirror->{'name'}.'</strong>';

    if ($mirror->{'url'} eq $sd->ENSEMBL_BASE_URL || ($key eq 'UK' && $sd->ENSEMBL_BASE_URL =~ /sanger/)) {
      push @$html, sprintf('%s %s - <span class="red">YOU ARE HERE!</span>', $flag, $site);
    } else {
      push @$html, sprintf('<a href="%s">%s</a> <a href="%1$s"><strong>%s</strong></a> - %s', 
        $mirror->{'url'}.'?redirect=no',
        $flag,
        $mirror->{'name'},
        $mirror->{'blurb'}
      );
    }
  }
  return join '', map sprintf('<p class="space-below">%s</p>', $_), @$html;
}

1;
