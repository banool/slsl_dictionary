- Are the signs the same regardless of the language? Currently I'm assuming that the same word in English, Tamil, Sinhara, etc. will have the same video.
- Will we ever want more than those 3 languages?
- For every word will we always have English, Tamil, and Sinhara? Or are the latter two best-effort but not always present?
- Ask more about how photos factor in to this.
- Clarify what kind of region information options there are?
    - All of Sri Lanka?
    - Tamil areas (???) only?
    - etc.
- I know there are multiple videos for a word. But is there anything special about those multiple videos? For the Auslan data they make the distinction between multiple videos for the same word + definition and videos for the same word but different definition.
- How do we want to handle related words? I feel it should not be like how (my scrape of) the Auslan data works where there are multiple identical (almost?) entries.
- The more I think about how much customization I want from the Django forms, the more I think maybe I should just roll this myself. I'd need to go learn about how Django works when it updates a model though, speciically with updates to existing entries.
   - I think when you think about how you have to search potentially in 3 different languages, it might make sense to have a checkbox where you select the language before you search. Further evidence for doing it on my own.
   - If I do, I gotta find a good form library, look into that one that I saw they use with Chakra.
   - I wonder if the admin frontend should actually just be Flutter.
   - For the backend I'd have to do my own auth, pagination, ORM stuff, CRUD
   - I should experiment first with how good the search is in Django when using different languages. If the 3 languages use different scripts (which I think they do?) then this will help a lot.