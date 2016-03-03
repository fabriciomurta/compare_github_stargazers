#!/usr/bin/perl

## Attention! If you don't have the JSON package installed, install it using:
# perl -MCPAN -e 'install JSON'

use LWP::UserAgent;
use JSON;

my $true = 1, $false = 0;

my $debug = $true,
   $base_url = "https://api.github.com/repos",
   $base_repo = "Saltarelle/SaltarelleCompiler",
   $compare_repo = "bridgedotnet/Bridge";

sub fetch_for {
 my $repo = shift,
    $outfile = shift,
    $next_page = 1,
    $ua = LWP::UserAgent->new(('ssl_opts' => { 'verify_hostname' => $false })),
    @entries = ();

 # Must declare on a second command line or else $repo don't get replaced correctly
 my $url = $base_url."/".$repo."/stargazers";

 open(FILEHANDLE, ">".$outfile);
 print FILEHANDLE "fetch date: ".localtime(time())."\n";
 while ($next_page > 0) {
  print("Querying ".$repo."'s stargazers page ".$next_page.": ");
  my $response = $ua->get($url."?page=".$next_page);

  if ($response->is_success) {
   unless ($response->code == 200) {
    print("failed.\n");
    print STDERR "*** Response ".$response->code." from '".$url."?page=".$next_page."'.\n";
    return;
   }
   print("done.\n");

   print("Dumping to '".$outfile."': ");
   print FILEHANDLE "Page ".$next_page." ===== begin.\n";
   print FILEHANDLE $response->decoded_content()."\n";
   print FILEHANDLE "Page ".$next_page." ===== end.\n";
   print("done.\n");

   my $link_header = $response->header("link"),
      $ratelim_remain = $response->header("x-ratelimit-remaining"),
      $ratelim_reset = $response->header("x-ratelimit-reset");

   if ($link_header =~ /[^0-9][0-9]+>; rel="next"/) {
    $next_page = $link_header =~ s/^.*[^0-9]([0-9]+)>; rel="next".*$/$1/r
   } else {
    $next_page = 0;
   }

   my @page_entries = @{decode_json($response->decoded_content())};
   
   foreach my $entry (@page_entries) {
    push(@entries, $entry);
   }
   
   print("next page: ".$next_page."\nremaining queries: ".$ratelim_remain.
    "\nreset time: ".localtime($ratelim_reset)." (".$ratelim_reset.")\n");
  } else {
   print("failed!\n");
   # FIXME: recover from errors instead of bailing out
   print STDERR "*** Unable to fetch url: ".$response->status_line."\n";
   return;
  }

  #$next_page = 0;
 }
 close(FILEHANDLE);

 return @entries;
}

local $|=1; # Flush stdout in realtime

my @base_entries = fetch_for($base_repo, "saltarelle-gazers.txt"),
   @compare_entries = fetch_for($compare_repo, "bridge-gazers.txt"),
   @unique_entries, $unique_count = 0;

print("Comparing user IDs on both lists: ");
foreach my $ref_entry (@base_entries) {
 my $ref_id = $ref_entry->{id};
 my $match = $false;
 foreach my $cmp_entry (@compare_entries) {
  my $cmp_id = $cmp_entry->{id};
  if ($ref_id eq $cmp_id) {
   #print("User ID '".$ref_id."' matched on bridge (".$cmp_id.").\n");
   $match = $true;
   last;
  }
 }
 if (not $match) {
  #print("Adding ".$ref_entry->{login}."/".$ref_id." as unique entry.\n");
  push(@unique_entries, $ref_entry);
  $unique_count++;
 }
}

print("done.\n\nUnique entries list:\n");

if ($unique_count < 1) {
 print("No unique entries.\n");
} else {
 open(CSVHANDLE, ">unique_users.csv");
 print CSVHANDLE "login, id, avatar_url, gravatar_id, url, html_url, followers_url, following_url, gists_url, ".
  "starred_url, subscriptions_url, organizations_url, repos_url, events_url, received_events_url, type, site_admin\n";
 foreach my $entry (@unique_entries) {
  print("User: ".$entry->{login}."\n");
  print CSVHANDLE $entry->{login}.", ".$entry->{id}.", ".$entry->{avatar_url}.", ".$entry->{gravatar_id}.", ".
   $entry->{url}.", ".$entry->{html_url}.", ".$entry->{followers_url}.", ".$entry->{following_url}.", ".
   $entry->{gists_url}.", ".$entry->{starred_url}.", ".$entry->{subscriptions_url}.", ".
   $entry->{organizations_url}.", ".$entry->{repos_url}.", ".$entry->{events_url}.", ".
   $entry->{received_events_url}.", ".$entry->{type}.", ".$entry->{site_admin}."\n";
 }
 close(CSVHANDLE);
 print(scalar(@unique_entries)." unique users out of a total of ".scalar(@base_entries)." star gazers on ".$base_repo."\n");
 print("Saved listing to 'unique_users.csv'.\n");
}
print("\nDone listing.\n");