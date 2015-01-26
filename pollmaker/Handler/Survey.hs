module Handler.Survey where

import Import
import Util.Util

data Survey = Survey {name :: String, questions :: [Question]} deriving (Show, Read)  
type Question = Text 
type Answer = Text

newtype SurveyAnswers = SurveyAnswers { answers:: [Answer] } deriving (Show, Read)  

instance ToJSON Survey where
    toJSON Survey{..} = object
        [ "name" .= name,
          "questions" .= questions 
        ]

dataFile :: String
dataFile = "data.txt"

answersFile :: String
answersFile = "answers.txt"

readSurvey :: IO Survey
readSurvey = do
        s <- getData dataFile 
        case s of
            Just x -> return x
            Nothing -> return $ Survey {name = "empty survey", questions = [] }

returnSurvey :: Text -> Handler Html
returnSurvey user 
    | user == "admin" = surveyPageEdit
    | otherwise = surveyPageRead

surveyPageEdit :: Handler Html
surveyPageEdit = defaultLayout $ do 
       s <- liftIO readSurvey 
       setTitle "Editing the Survey"
       $(widgetFile "surveyEdit")

surveyPageRead :: Handler Html
surveyPageRead = defaultLayout $ do 
       s <- liftIO readSurvey 
       setTitle "Filling out the Survey"
       $(widgetFile "surveyRead")

getSurveyR :: Handler Html
getSurveyR = do
  v <- lookupSession "logged"
  case v of 
       Just u -> returnSurvey u
       Nothing -> redirect LoginR

postCreateSurveyR :: Handler Html
postCreateSurveyR = do
  (postData, _) <- runRequestBody
  let qs = map snd postData
      s = Survey { name = "test survey", questions = qs }
  liftIO $ saveData s dataFile
  defaultLayout [whamlet|<p>#{show s}|]


postSurveyR :: Handler Html
postSurveyR = do
  (postData, _) <- runRequestBody
  let qs = map snd postData
      a = SurveyAnswers { answers = qs }
  liftIO $ appendData a answersFile
  defaultLayout [whamlet|<p>#{show "thank you"}|]


