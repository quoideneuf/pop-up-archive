angular.module('Directory.faq.controllers', ['Directory.loader', 'Directory.user'])
.controller('FAQController', ['$scope', 'Me', '$location', '$anchorScroll', function ItemsCtrl($scope, Me, $location, $anchorScroll) {

	$scope.scrollTo = function(link) {
		console.log('clicked');
		console.log(link);
    	$location.hash(link);
     	$anchorScroll();
	}

	$scope.faq = [
		{
			title: "Getting Started",
			link: "get_started",
			questions: [

				{
					question: "What is Pop Up Archive? Who is it for?",
					answer: "Pop Up Archive is a tool for simple management of speech-based audio. We process sound for a wide range of clients, from large archives and religious institutions to independent podcasters and researchers; if you’ve got recorded voices, we’ve got you. Drag and drop any speech-based audio file, and within minutes you’ll receive automatically generated transcripts and tags. By automatically extracting the information from your audio, we save you hours of manual labor and let you quickly search and organize your audio collections; no more sorting and listening through entire hour long files to find that one line you’re looking for.",
				},
				{
					question: "How does Pop Up Archive compare to human transcription?",
					answer: "The short answer is that automatic transcription isn’t perfect, but neither is human transcription. Getting verbatim human transcripts is expensive, slow and labor-intensive. Plus, not all humans transcribe alike - you still need to find someone who knows the dialect of your audio’s speakers well enough to understand them with perfect accuracy. In contrast, our speech-to-text software is trained on many voices, so it automatically interprets English dialects from all over the world. Our auto-transcripts may require a little editing love to get to publishable quality, but with our built-in transcript editing workspace, our system is way faster than starting from scratch, and allows you to search broadly within your collections within minutes.",
				},
				{	
					question: "What does it mean to “search my sound?",
					answer: "In addition to our standard search bar, and the search bar for each collection, there is also a search bar for each individual audio item, allowing you to search for every time a word or phrase was transcribed within a single item."
				},
			]
		},
		{
			title: "Sharing Audio",
			link: "sharing_audio",
			questions: [
				{
					question: "How can a share an audio file on my blog?",
					answer: "That’s what our embeddable player is for. Copy the html code from our “embed” button for an audio item, and paste it into the html on your WordPress, Tumblr, or other blog. It does not work on social sites like Facebook and Twitter. To share audio socially, simply copy the link to the audio item that you’d like to share. Read a tutorial here: http://popuparchive.tumblr.com/post/78816510638/for-you-a-brand-spanking-new-embeddable-player-and. For sites powered by WordPress, we also have a Pop Up Archive plugin that allows your to search your collections and integrate automatic tags right on your blog: http://popuparchive.tumblr.com/post/89803900359/add-automatic-tags-to-your-audio-posts-in-wordpress",
				},
				{
					question: "Can I embed just a certain section of audio?",
					answer: "We’re working on it. Right now, you can share our audio either by copying the site link or by copying the embed code.",
				},
				{
					question: "How do I share audio on my WordPress site?",
					answer: "We’ve got a plugin for that! Read about how it works: http://popuparchive.tumblr.com/post/89803900359/add-automatic-tags-to-your-audio-posts-in-wordpress or download now: https://github.com/popuparchive/popuparchive-wp",
				}
			]
		},
		{
			title: "File Upload",
			link: "file_upload",
			questions: [
				{
					question: "What is the difference between 'unsorted audio' and 'collections?'",
					answer: "If you’ve got a lot of files and aren’t sure how to organize them yet, upload them all to the unsorted area. Our playback, audio analysis, and privacy features apply only to collections, not unsorted audio. Once you’ve created the right collections, drag and drop the unsorted audio to the collection you want, and Pop Up Archive instantly starts processing your sound for automatic transcripts and tags. You can track the upload status of your audio with our status bars, and you’ll be notified by email when your automatic transcripts and tags have been generated.",
				},
				{
					question: "What kind of audio file formats can I upload?",
					answer: "Pop Up Archive currently supports the following file formats: 'aac', 'aif', 'aiff', 'alac', 'flac', 'm4a', 'm4p', 'mp2', 'mp3', 'mp4', 'ogg', 'raw', 'spx', 'wav', 'wma'. Email us (edison@popuparchiveorg.zendesk.com) if your file won't upload!",
				},
				{
					question: "What kind of image file formats can I upload?",
					answer: "Pop Up Archive accepts jpg and png format images.",
				},
				{
					question: "What is the maximum file size?",
					answer: "Our upload technology is pretty robust, so go ahead and try the biggest file you've got. It's mostly a question of Internet connection speed and browser responsiveness. Problems? If you're willing to share info about your browser and the file(s) giving you trouble, it will help us out a lot. Email us with the size and file type of the audio. If possible, include a link to the item and the name of the file. You can also email our help desk at edison@popuparchive.org.",
				},
				{
					question: "I have an interview that is saved on my computer as multiple audio files. Can I add them together for one transcript?",
					answer: "You sure can! In the upload form, simply click “add to audio item,” select the next audio file, and repeat for as many files as you would like to add onto a single audio item page. The files will remain separate, but playback from one audio file to the next will be automatic on the item page.",
				},
				{
					question: "I have an RSS feed for my audio on Soundcloud (iTunes, etc.) Can I set this feed up to import automatically to Pop Up Archive?",
					answer: "Right now, RSS feed integration is only available for enterprise plans. If you’re an enterprise client, contact us for help setting it up.",
				},
				{
					question: "I'm having trouble entering dates: when I enter a year of 07, it's displayed as 0007 rather than 2007.",
					answer: "You must enter years as four digits. You can use our Date Picker to avoid this problem. From the 'Item Edit' view, click the calendar icon to select a date: Pro tip: If you click the month (i.e. May 2013), you can easily switch between years."
				}
			]
		},
		{
			title: "Privacy",
			link: "privacy",
			questions: [
				{
					question: "How do I specify the privacy setting for an audio item?",
					answer: "While creating a collection, you must specify a privacy setting. Privacy settings belong only to collections, not individual audio items. The audio in the unsorted audio space is not playable, therefore not subject to privacy specification. Your first collection that appears after sign up is private, with all audio stored on Amazon S3 servers.",
				},
				{
					question: "What are public collections and where are they stored?",
					answer: "Media in public collections is visible to anyone on the web. Anyone can see or hear audio in public collections through Pop Up Archive’s website, which is indexed by Google like any other public website. Currently, no one can download material directly from the Pop Up Archive website unless they are an owner of the material. You can choose to store public collections either on Amazon S3 servers maintained by Pop Up Archive, or on servers at the Internet Archive (archive.org).",
				},
				{
					question: "What are private collections and where are they stored?",
					answer: "A private collection can be seen and heard only by the person who created it. Media in private collections is stored on private Amazon S3 servers maintained by Pop Up Archive. Private team collections (contact us if you're interested) can only be seen and heard by team members who have been granted access by the team administrator.",
				},
				{
					question: "What is the Internet Archive?",
					answer: "Like a public library, the Internet Archive stores media and makes it available at no cost to researchers, historians, and scholars. Public collections stored at the Internet Archive can be seen, heard, and downloaded through the Internet Archive's website, which is also indexed by Google.",
				},
				{
					question: "Who can access my audio if it’s in a public collection?",
					answer: "Anyone can access audio in a public collection through Pop Up Archive’s website. No one can download material directly from Pop Up Archive website unless they are an owner of that material. If your public collection is stored at the Internet Archive, it can be accessed through Pop Up Archive’s website as well as through the Internet Archive. Audio stored at the Internet Archive can also be downloaded from the Internet Archive’s website.",
				},
				{
					question: "Who can access my audio if it’s in a private collection?",
					answer: "A private collection can be seen and heard only by the person who created it. Private team collections are only visible to team members who have been granted access by the team administrator. Contact us if you're interested in creating a team collection.",
				},
				{
					question: "I accidentally added private audio to a public collection. Now what?",
					answer: "Privacy is set at the collection level. If you've added your audio to an Internet Archive collection and would like to have it removed, contact us. If you're audio is in a non-Internet Archive public collection, you can move it to a private collection by selecting the item, clicking edit, and selecting a private collection from the Collection pulldown menu.",
				},
				{
					question: "I see my private collection when I search collections from the explore page! Does this mean it’s public?",
					answer: "No, your own collection is only visible on the explore page while you are logged in.",
				},
			]
		},
		{
			title: "Transcripts and Audio Quality",
			link: "transcripts",
			questions: [
				{
					question: "How do I view transcripts?",
					answer: "You should be able to find the transcript in the space directly below the audio file player and waveform. If you click the blue \"Expand\" button in the top right corner, you can see the entire transcript at once. The numbers (0-6, 5-11) are timestamps in seconds. You can play any timestamp by clicking the small play button next to that row. Click the pencils on the right side of each row to edit the transcript text. In some cases, if your audio quality is poor, the file does not auto-transcribe very well. The transcript may only have a few words. You can read more about audio quality guidelines in the transcript editing question.",
				},
				{
					question: "Where are the transcripts coming from?",
					answer: "Machine translation isn’t perfect, but it’s getting better. We’re committed to seeking out state of the art automatic speech recognition, and regularly integrate improvements. In other words, your automatically generated data will only get better and better, so watch out.",
				},
				{
					question: "Why do my automatic transcripts and tags have errors?",
					answer: "Automatically generated transcripts rely on software to make a guess about what's being said in your audio file. Your transcript will have more or less errors depending on the quality of the audio. For instance, broadcast-quality news productions and interviews recorded with high-quality equipment result in the most accurate transcripts because there is little background noise.",
				},
				{
					question: "What affects my transcript quailty?",
					answer: "Transcript quality may be adversely affected by the subject speaking quickly, with an accent, or mumbling; multiple speakers speaking at the same time; background noise; or background music tracks. Pop Up Archive also uses keyword extraction tools that pull useful terms from your transcripts, so even if your transcripts aren't perfect, we can still extract valuable information from them.",
				},
				{
					question: "Not all of my automatic tags make sense. How do I delete them?",
					answer: "You can clear all of the suggested automatic tags by clicking “clear suggested,” or cancel individual tags with the “x” button. To confirm an auto-tag so that it becomes an official tag for your audio item, click the check mark. See an example here: http://popuparchive.tumblr.com/post/83715677236/new-tricks-on-pop-up-archive-easy-transcript-editing",
				},
				{
					question: "I haven’t received a notification about my transcript, and it’s been days!",
					answer: "If it’s been a long time since upload, and your audio still hasn’t been processed for auto-transcripts and tags, the first line of attack is to make sure you’re uploading a supported file format, and retry the upload. If it still isn’t working, email us at edison@popuparchive.com.",
				},
				{
					question: "I deleted all my automatic tags but they still show up in the search page.",
					answer: "If your deleted auto-tags are still showing up, that means the site hasn’t processed the changed yet. If they are still showing up a day or two later, contact us at edison@popuparchive.com",
				},
				{
					question: "How do I edit my transcripts?",
					answer: "Read this post to learn about our transcript editing: http://popuparchive.tumblr.com/post/83715677236/new-tricks-on-pop-up-archive-easy-transcript-editing",
				},
				{
					question: "Why did my transcript edits disappear when I navigated away from my audio item page!",
					anser: "Be sure that you wait until the entire auto-transcript has been generated for your file before cleaning up your transcript - otherwise the auto-transcript will write over your edits.",
				},
			]
		},
		{
			title: "Pop Up Archive Membership and Payment",
			link: "membership",
			questions: [
				{
					question: "Can I start with a monthly plan, and switch over to an annual plan?",
					answer: "If you start with a monthly plan and decide that you like Pop Up Archive enough to get our discounted annual rate, you can switch to an annual plan anytime. You will be charged the annual rate from the day you switch over, with the last month of your monthly plan to be paid in full.",
				},
				{
					question: "When and how am I charged?",
					answer: "For monthly plans, you’ll be charged once each month, from the day you signed up. For annual plans, you’ll be charged once a year from the day of sign up. We use Stripe to process payments.",
				},
				{
					question: "What does “hours of processing” mean exactly?",
					answer: "Each month, you can upload the amount of hours allocated to your plan, and we’ll automatically generate transcripts, tags. You’ll be able to access all your audio on our site as long as you’re a subscriber.",
				},
				{
					question: "Does the hourly limit reset each month?",
					answer: "Yes, you will be able to upload the number of hours available to your plan EACH month.",
				},
				{
					question: "I’d like for my whole audio team to use Pop Up Archive. Is there a team plan?",
					answer: "Yes, you can add multiple users to the Small Business and Enterprise plans. Email edison@popuparchive.com for more information."
				},
				{
					question: "Can I cancel at any time?",
					answer: "Yes, absolutely. Just click your user name (next to the Pop Up Archive logo) and select “my account”. You can then click “Change My Plan”  and select the Free Plan to downgrade your account. You will not be charged again unless you choose to upgrade. You have a 30 day grace period of access to your audio. In addition, all uploads to the Internet Archive will remain available at archive.org.",
				},
				// {
				// 	question: "What happens if I go over my hour limit?",
				// 	answer: "Don’t worry, you’ll receive an email from edison@popuparchive.com alerting you that you’ve reached your limit. You’ll be charged for any audio that you add over the set hourly limit.",
				// },
			]
		},
		{
			title: "Troubleshooting",
			link: "troubleshooting",
			questions: [
				{
					question: "Why isn't the auto-generated transcript showing?",
					answer: "Transcription takes place in real time. Pop Up Archive begins by transcribing the first 120 seconds of your audio, which should take just a couple minutes. (If not, let us know!) Then, if you're uploading to the Internet Archive or on a paid plan, the rest of the transcript will appear once the entire file has finished processing. For instance, if your audio file is an hour long, it will take at least an hour for the full transcription to generate. You'll get an email from us when the full transcript is up.",
				},
			]
		}
	]
}]);